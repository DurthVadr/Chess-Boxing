#!/usr/bin/env python3
"""
Fetch chess puzzles from the Lichess puzzle database and save to local JSON pools.

The Lichess DB CSV format:
  PuzzleId,FEN,Moves,Rating,RatingDeviation,Popularity,NbPlays,Themes,GameUrl,OpeningTags

Moves are space-separated UCI. The first move is the "setup move" (opponent's last move
before the puzzle begins). We apply it to the FEN to get the puzzle position, then store
the remaining moves as the solution.

Usage:
  python tools/fetch_puzzles.py                  # Default: 30 easy, 25 medium, 20 hard
  python tools/fetch_puzzles.py --easy 50 --medium 40 --hard 30
  python tools/fetch_puzzles.py --append          # Add to existing puzzles instead of replacing
"""

import argparse
import csv
import io
import json
import os
import random
import sys
from pathlib import Path

import chess
import requests
import zstandard as zstd

LICHESS_DB_URL = "https://database.lichess.org/lichess_db_puzzle.csv.zst"
DATA_DIR = Path(__file__).resolve().parent.parent / "data" / "puzzles"

# Rating brackets mapping to our difficulty 1-5
BRACKETS = {
    "easy":   {"min_rating": 600,  "max_rating": 1400, "difficulty_range": (1, 2)},
    "medium": {"min_rating": 1400, "max_rating": 1900, "difficulty_range": (3, 4)},
    "hard":   {"min_rating": 1900, "max_rating": 2800, "difficulty_range": (4, 5)},
}

# Themes we like for the game (good visual/conceptual puzzles)
GOOD_THEMES = {
    "mateIn1", "mateIn2", "mateIn3", "fork", "pin", "skewer",
    "discoveredAttack", "sacrifice", "deflection", "backRankMate",
    "smotheredMate", "hookMate", "arabianMate", "attraction",
    "clearance", "interference", "hangingPiece", "trappedPiece",
    "doubleCheck", "quietMove", "zugzwang", "xRayAttack",
}

# Min player moves (after setup move removed)
MIN_PLAYER_MOVES = 1
MAX_PLAYER_MOVES = 5


def rating_to_difficulty(rating: int) -> int:
    if rating < 1000:
        return 1
    elif rating < 1400:
        return 2
    elif rating < 1700:
        return 3
    elif rating < 2100:
        return 4
    else:
        return 5


def convert_puzzle(row: dict) -> dict | None:
    """Convert a Lichess CSV row to our internal puzzle format."""
    try:
        fen = row["FEN"]
        moves_str = row["Moves"]
        rating = int(row["Rating"])
        popularity = int(row["Popularity"])
        themes_str = row["Themes"]
        puzzle_id = row["PuzzleId"]
    except (KeyError, ValueError):
        return None

    # Filter: need decent popularity and not too niche
    if popularity < 50:
        return None

    moves = moves_str.strip().split()
    if len(moves) < 2:
        return None

    # Apply setup move to get puzzle position
    setup_move = moves[0]
    solution = moves[1:]

    # Count player moves (indices 0, 2, 4... in solution)
    player_move_count = (len(solution) + 1) // 2
    if player_move_count < MIN_PLAYER_MOVES or player_move_count > MAX_PLAYER_MOVES:
        return None

    # Use python-chess to apply the setup move and get the resulting FEN
    try:
        board = chess.Board(fen)
        move = chess.Move.from_uci(setup_move)
        if move not in board.legal_moves:
            return None
        board.push(move)
        puzzle_fen = board.fen()
    except (ValueError, chess.InvalidMoveError):
        return None

    # Validate all solution moves are legal
    test_board = board.copy()
    for uci_move in solution:
        try:
            m = chess.Move.from_uci(uci_move)
            if m not in test_board.legal_moves:
                return None
            test_board.push(m)
        except (ValueError, chess.InvalidMoveError):
            return None

    themes = [t for t in themes_str.strip().split() if t] if themes_str else []
    difficulty = rating_to_difficulty(rating)

    # Build description from themes
    display_themes = [
        "mateIn1", "mateIn2", "mateIn3", "fork", "pin",
        "discoveredAttack", "sacrifice", "deflection", "skewer",
        "backRankMate", "smotheredMate", "hookMate", "arabianMate",
    ]
    theme_label = ""
    for t in display_themes:
        if t in themes:
            # CamelCase to spaced
            label = ""
            for ch in t:
                if ch.isupper() and label:
                    label += " "
                label += ch
            theme_label = label.title()
            break
    if not theme_label:
        theme_label = themes[0].title() if themes else "Tactics"

    moves_text = f"{player_move_count} move{'s' if player_move_count != 1 else ''}"
    description = f"{theme_label} — Find the best {moves_text}!"

    return {
        "id": f"lichess_{puzzle_id}",
        "fen": puzzle_fen,
        "solution": solution,
        "themes": themes,
        "difficulty": difficulty,
        "rating": rating,
        "description": description,
        "source": "lichess",
    }


def stream_puzzles(target_counts: dict[str, int]) -> dict[str, list]:
    """Stream the Lichess puzzle DB and collect puzzles for each bracket."""
    pools = {"easy": [], "medium": [], "hard": []}
    # Collect extra candidates so we can pick the best
    OVERSAMPLE = 5
    candidates = {"easy": [], "medium": [], "hard": []}
    targets = {k: v * OVERSAMPLE for k, v in target_counts.items()}

    total_needed = sum(targets.values())
    total_collected = 0

    print(f"Downloading Lichess puzzle database (streaming)...")
    print(f"Targets: easy={target_counts['easy']}, medium={target_counts['medium']}, hard={target_counts['hard']}")

    resp = requests.get(LICHESS_DB_URL, stream=True, timeout=30)
    resp.raise_for_status()

    dctx = zstd.ZstdDecompressor()
    reader = dctx.stream_reader(resp.raw)
    text_reader = io.TextIOWrapper(reader, encoding="utf-8")
    csv_reader = csv.DictReader(text_reader)

    rows_checked = 0
    for row in csv_reader:
        rows_checked += 1

        # Early exit once we have enough candidates
        if total_collected >= total_needed:
            break

        # Check which bracket this rating falls in
        try:
            rating = int(row["Rating"])
        except (KeyError, ValueError):
            continue

        bracket = None
        for name, cfg in BRACKETS.items():
            if cfg["min_rating"] <= rating < cfg["max_rating"]:
                bracket = name
                break

        if bracket is None:
            continue
        if len(candidates[bracket]) >= targets[bracket]:
            continue

        puzzle = convert_puzzle(row)
        if puzzle is None:
            continue

        # Prefer puzzles with interesting themes
        theme_set = set(puzzle["themes"])
        has_good_theme = bool(theme_set & GOOD_THEMES)
        candidates[bracket].append((puzzle, has_good_theme))
        total_collected += 1

        if rows_checked % 50000 == 0:
            counts = {k: len(v) for k, v in candidates.items()}
            print(f"  Checked {rows_checked:,} rows... candidates: {counts}")

    print(f"  Done streaming. Checked {rows_checked:,} rows total.")

    # Select the best puzzles from candidates
    for bracket, target in target_counts.items():
        cands = candidates[bracket]
        # Sort: good themes first, then shuffle within
        good = [p for p, has_good in cands if has_good]
        rest = [p for p, has_good in cands if not has_good]
        random.shuffle(good)
        random.shuffle(rest)
        selected = (good + rest)[:target]
        pools[bracket] = selected

    return pools


def load_existing(filepath: Path) -> list:
    if filepath.exists():
        with open(filepath, "r", encoding="utf-8") as f:
            return json.load(f)
    return []


def save_pool(filepath: Path, puzzles: list):
    filepath.parent.mkdir(parents=True, exist_ok=True)
    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(puzzles, f, indent=2, ensure_ascii=False)
    print(f"  Saved {len(puzzles)} puzzles to {filepath.name}")


def main():
    parser = argparse.ArgumentParser(description="Fetch Lichess puzzles for local pools")
    parser.add_argument("--easy", type=int, default=30, help="Number of easy puzzles")
    parser.add_argument("--medium", type=int, default=25, help="Number of medium puzzles")
    parser.add_argument("--hard", type=int, default=20, help="Number of hard puzzles")
    parser.add_argument("--append", action="store_true", help="Append to existing puzzles")
    args = parser.parse_args()

    target_counts = {"easy": args.easy, "medium": args.medium, "hard": args.hard}

    pools = stream_puzzles(target_counts)

    files = {
        "easy": DATA_DIR / "puzzles_easy.json",
        "medium": DATA_DIR / "puzzles_medium.json",
        "hard": DATA_DIR / "puzzles_hard.json",
    }

    print("\nSaving puzzles...")
    for bracket, filepath in files.items():
        new_puzzles = pools[bracket]
        if args.append:
            existing = load_existing(filepath)
            # Deduplicate by ID
            existing_ids = {p["id"] for p in existing}
            new_puzzles = [p for p in new_puzzles if p["id"] not in existing_ids]
            combined = existing + new_puzzles
            save_pool(filepath, combined)
            print(f"    ({len(new_puzzles)} new, {len(existing)} existing)")
        else:
            save_pool(filepath, new_puzzles)

    total = sum(len(pools[b]) for b in pools)
    print(f"\nDone! {total} puzzles total across all pools.")


if __name__ == "__main__":
    main()
