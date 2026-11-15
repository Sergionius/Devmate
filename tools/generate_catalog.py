"""Regenerate lib/data/question_catalog.dart from locale JSON sources.

Keep questions in assets/data/questions.json (ru) and
assets/data/questions_en.json (en); after editing run:
    python3 tools/generate_catalog.py
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = {
    "ru": ROOT / "assets/data/questions.json",
    "en": ROOT / "assets/data/questions_en.json",
}
TARGET = ROOT / "lib/data/question_catalog.dart"


def dart_string(value: str) -> str:
    escaped = (
        value.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("$", r"\$")
        .replace("\n", "\\n")
    )
    return f"'{escaped}'"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def fingerprint(data: dict) -> list[tuple[str, list[str]]]:
    return [
        (topic["id"], [question["id"] for question in topic["questions"]])
        for topic in data["topics"]
    ]


def render_locale(data: dict, const_name: str) -> str:
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
    return f"const {const_name} = <InterviewTopic>[\n{body}\n];\n"


def main() -> None:
    data_by_locale = {locale: load(path) for locale, path in SOURCES.items()}
    fingerprints = {locale: fingerprint(data) for locale, data in data_by_locale.items()}
    reference = fingerprints["ru"]
    for locale, marks in fingerprints.items():
        if marks != reference:
            raise SystemExit(f"{locale} catalog ids/order diverge from ru")
    total = sum(len(t["questions"]) for t in data_by_locale["ru"]["topics"])
    content = (
        "// GENERATED FILE — do not edit by hand.\n"
        "// Sources: assets/data/questions.json (ru),"
        " assets/data/questions_en.json (en).\n"
        "// Regenerate with: python3 tools/generate_catalog.py\n"
        "import '../domain/question.dart';\n\n"
        + render_locale(data_by_locale["ru"], "questionCatalogRu")
        + "\n"
        + render_locale(data_by_locale["en"], "questionCatalogEn")
        + "\nconst questionCatalog = questionCatalogRu;\n\n"
        "List<InterviewTopic> questionCatalogFor(String languageCode) =>\n"
        "    languageCode == 'ru' ? questionCatalogRu : questionCatalogEn;\n\n"
        "InterviewTopic? topicById(String id) {\n"
        "  for (final topic in questionCatalog) {\n"
        "    if (topic.id == id) return topic;\n"
        "  }\n"
        "  return null;\n"
        "}\n"
    )
    TARGET.write_text(content, encoding="utf-8")
    print(
        f"Wrote {TARGET.relative_to(ROOT)}:"
        f" {len(data_by_locale['ru']['topics'])} topics,"
        f" {total} questions x {len(data_by_locale)} locales."
    )


if __name__ == "__main__":
    main()
