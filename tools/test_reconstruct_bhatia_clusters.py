import csv

import numpy as np

from tools import reconstruct_bhatia_clusters as bhatia


def test_attribute_rows_keep_bhatia_shape_and_direction_order():
    rows = bhatia.load_attribute_rows(bhatia.DEFAULT_ATTRIBUTES_CSV)

    bhatia.validate_attribute_direction_order(rows)

    assert len(rows) == 414
    assert len(bhatia.unique_attribute_rows(rows)) == 207
    assert len(bhatia.direction_indices(rows, "pro")) == 207
    assert len(bhatia.direction_indices(rows, "con")) == 207
    assert bhatia.unique_attribute_rows(rows)[0].name == "gains vs. losses"


def test_reference_mpnet_vectors_align_with_attribute_rows():
    rows = bhatia.load_attribute_rows(bhatia.DEFAULT_ATTRIBUTES_CSV)
    pro, con = bhatia.load_attribute_vectors(bhatia.DEFAULT_ATTRIBUTE_VECTORS, rows)

    assert pro.shape == (207, 768)
    assert con.shape == (207, 768)
    assert np.all(np.linalg.norm(pro, axis=1) > 0.99)
    assert np.all(np.linalg.norm(con, axis=1) > 0.99)


def test_score_column_names_match_bhatia_step5_order():
    columns = bhatia.score_column_names(attribute_count=3)

    assert columns == [
        "choice1_benefits1",
        "choice1_benefits2",
        "choice1_benefits3",
        "choice1_costs1",
        "choice1_costs2",
        "choice1_costs3",
        "choice2_benefits1",
        "choice2_benefits2",
        "choice2_benefits3",
        "choice2_costs1",
        "choice2_costs2",
        "choice2_costs3",
    ]


def test_complete_reason_rows_filter_missing_values(tmp_path):
    path = tmp_path / "advice.csv"
    fieldnames = ["id"] + bhatia.REASON_COLUMNS
    complete = {"id": "ok", **{column: f"{column} text" for column in bhatia.REASON_COLUMNS}}
    incomplete = complete | {"id": "bad", bhatia.REASON_COLUMNS[-1]: "NA"}

    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerow(incomplete)
        writer.writerow(complete)

    rows = list(bhatia.iter_complete_reason_rows(path))
    stats = bhatia.count_reason_stats(path)

    assert [row["id"] for _, row in rows] == ["ok"]
    assert stats.total_rows == 2
    assert stats.complete_rows == 1
    assert stats.incomplete_rows == 1
    assert stats.unique_reasons == len(bhatia.REASON_COLUMNS)
