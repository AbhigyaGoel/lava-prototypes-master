"""Integration tests against real Icarus/Yosys (skipped if the tools are missing)."""
import pytest

from assay.common import which
from assay.eda import equivalence, simulate

pytestmark = pytest.mark.skipif(not (which("yosys") and which("iverilog")), reason="EDA tools not installed")

GOLD = "module m(input [1:0] a, output y); assign y = a[0] & a[1]; endmodule\n"
OR_ = "module m(input [1:0] a, output y); assign y = a[0] | a[1]; endmodule\n"
SEQ_GOLD = """module c(input clk, input rst, input en, output reg [3:0] q);
always @(posedge clk) if (rst) q <= 0; else if (en) q <= q + 1; endmodule
"""
SEQ_BUG = SEQ_GOLD.replace("else if (en) q <= q + 1", "else q <= q + 1")


def _w(tmp_path, name, text):
    p = tmp_path / name
    p.write_text(text)
    return p


def test_comb_mismatch_where_gold_is_zero_is_caught(tmp_path):
    # Regression: miter -ignore_gold_x without undef modelling reported this as proven.
    g, b = _w(tmp_path, "g.v", GOLD), _w(tmp_path, "b.v", OR_)
    assert equivalence(g, [b], {"module": "m", "equiv_mode": "comb"})["result"] == "failed"
    assert equivalence(g, [g], {"module": "m", "equiv_mode": "comb"})["result"] == "proven"


def test_seq_equivalence(tmp_path):
    meta = {"module": "c", "equiv_mode": "seq", "reset": {"port": "rst", "active": 1}}
    g, b = _w(tmp_path, "g.v", SEQ_GOLD), _w(tmp_path, "b.v", SEQ_BUG)
    assert equivalence(g, [g], meta)["result"] == "proven"
    assert equivalence(g, [b], meta)["result"] == "failed"


def test_simulate_pass_and_compile_error(tmp_path):
    tb = _w(tmp_path, "tb.v", 'module tb; reg [1:0] a = 3; wire y; m d(.a(a), .y(y));\n'
                               'initial begin #1 if (y !== 1) $display("FAIL"); else $display("TEST PASSED"); $finish; end endmodule\n')
    assert simulate(tb, [_w(tmp_path, "g.v", GOLD)])["passed"]
    bad = simulate(tb, [_w(tmp_path, "x.v", "module m(input a output y); endmodule\n")])
    assert not bad["passed"] and bad["reason"] == "compile_error"
