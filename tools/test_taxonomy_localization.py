from pathlib import Path
import csv
import json


CLUSTER_MAPPING = Path("DecisionKernel/Resources/Attributes/bhatia_attribute_clusters.csv")
TAXONOMY_LOCALIZATION = Path("dilemma/Sources/Resources/TaxonomyLocalization.json")


def test_taxonomy_localization_covers_bhatia_clusters_and_attributes():
    with CLUSTER_MAPPING.open(newline="", encoding="utf-8") as handle:
        mapping_rows = list(csv.DictReader(handle))
    taxonomy = json.loads(TAXONOMY_LOCALIZATION.read_text(encoding="utf-8"))

    source_clusters = {}
    source_attributes = {}
    for row in mapping_rows:
        cluster_id = int(row["cluster_id"])
        source_clusters.setdefault(cluster_id, row["cluster_label"])
        source_attributes[int(row["attribute_id"])] = row["attribute_name"]

    localized_clusters = {row["id"]: row for row in taxonomy["clusters"]}
    localized_attributes = {row["id"]: row for row in taxonomy["attributes"]}

    assert set(localized_clusters) == set(range(1, 26))
    assert set(localized_attributes) == set(source_attributes)
    assert {row["source"] for row in localized_clusters.values()} == set(source_clusters.values())

    for attribute_id, source_name in source_attributes.items():
        row = localized_attributes[attribute_id]
        assert row["source"] == source_name
        assert row["ru"].strip()

    for cluster_id, source_label in source_clusters.items():
        row = localized_clusters[cluster_id]
        assert row["source"] == source_label
        assert row["en"].strip()
        assert row["ru"].strip()


def test_taxonomy_localization_display_contract():
    taxonomy = json.loads(TAXONOMY_LOCALIZATION.read_text(encoding="utf-8"))
    clusters = {row["id"]: row for row in taxonomy["clusters"]}
    attributes = {row["source"]: row for row in taxonomy["attributes"]}

    assert clusters[20]["source"] == "Sex and Romance"
    assert clusters[20]["en"] == "Romance"
    assert clusters[20]["ru"] == "Романтические отношения"

    assert attributes["money"]["ru"] == "деньги"
    assert attributes["health"]["ru"] == "здоровье"
    assert attributes["being close to my children"]["ru"] == "близость с детьми"
