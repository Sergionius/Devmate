"""Regenerate lib/data/question_catalog.dart from assets/data/questions.json.

Keep questions in the JSON file; after editing run:
    python3 tools/generate_catalog.py
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/data/questions.json"
TARGET = ROOT / "lib/data/question_catalog.dart"


def dart_string(value: str) -> str:
    escaped = (
        value.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("$", r"\$")
        .replace("\n", "\\n")
    )
    return f"'{escaped}'"


def main() -> None:
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    seen_question_ids: set[str] = set()
    topic_ids: set[str] = set()
    blocks: list[str] = []
    for topic in data["topics"]:
        if topic["id"] in topic_ids:
            raise SystemExit(f"Duplicate topic id: {topic['id']}")
        topic_ids.add(topic["id"])
        questions: list[str] = []
        for question in topic["questions"]:
            if question["id"] in seen_question_ids:
                raise SystemExit(f"Duplicate question id: {question['id']}")
            seen_question_ids.add(question["id"])
            questions.append(
                "      InterviewQuestion(\n"
                f"        {dart_string(question['id'])},\n"
                f"        {dart_string(question['prompt'])},\n"
                f"        {dart_string(question['answer'])},\n"
                "      ),"
            )
        blocks.append(
            "  InterviewTopic(\n"
            f"    {dart_string(topic['id'])},\n"
            f"    {dart_string(topic['title'])},\n"
            f"    {dart_string(topic['description'])},\n"
            "    [\n" + "\n".join(questions) + "\n    ],\n  ),"
        )

    body = "\n".join(blocks)
    content = (
        "// GENERATED FILE — do not edit by hand.\n"
        "// Source: assets/data/questions.json. Regenerate with:\n"
        "//   python3 tools/generate_catalog.py\n"
        "import '../domain/question.dart';\n\n"
        "const questionCatalog = <InterviewTopic>[\n"
        f"{body}\n"
        "];\n\n"
        "InterviewTopic? topicById(String id) {\n"
        "  for (final topic in questionCatalog) {\n"
        "    if (topic.id == id) return topic;\n"
        "  }\n"
        "  return null;\n"
        "}\n"
    )
    TARGET.write_text(content, encoding="utf-8")
    total = sum(len(t["questions"]) for t in data["topics"])
    print(f"Wrote {TARGET.relative_to(ROOT)}: {len(data['topics'])} topics, {total} questions.")


if __name__ == "__main__":
    main()
