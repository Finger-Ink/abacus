defmodule AbacusNumberTest do
  use ExUnit.Case

  alias Abacus.Number

  # One half of the cross-engine coercion contract; the JS half is
  # `extractNumber` in the Finger-Ink cloud repo, pinned by the shared
  # numeric_coercion_cases.json fixture there.

  describe "extract/1 accepts" do
    @accepts [
      {"integer", 1180, 1180},
      {"float", 72.5, 72.5},
      {"clean numeric string", "1180", 1180},
      {"trailing whitespace", "1180 ", 1180},
      {"surrounding whitespace", " 1180 ", 1180},
      {"newline", "1180\n", 1180},
      {"non-breaking space", "1180 ", 1180},
      {"narrow NBSP and thin space", " 1180 ", 1180},
      {"zero-width space", "​1180​", 1180},
      {"leading plus", "+5", 5},
      {"negative", "-250", -250},
      {"leading zeros", "007", 7},
      {"bare leading decimal point", ".5", 0.5},
      {"bare trailing decimal point", "5.", 5},
      {"whole float collapses to integer", "5.0", 5},
      {"plain decimal", "1.5", 1.5},
      {"dot is never euro grouping", "1.500", 1.5},
      {"leading currency", "$1180", 1180},
      {"leading currency with space", "$ 1180", 1180},
      {"trailing currency with space", "1180 €", 1180},
      {"currency with decimal", "£99.50", 99.5},
      {"trailing percent", "50%", 50},
      {"trailing percent with space", "50 %", 50},
      {"decimal percent", "12.5%", 12.5},
      {"comma grouping", "1,180", 1180},
      {"repeated comma grouping", "1,500,000", 1_500_000},
      {"decimal comma", "72,5", 72.5},
      {"decimal comma, long fraction", "3,1415", 3.1415},
      {"decimal comma, two-digit fraction", "1,18", 1.18},
      {"euro mixed separators", "1.180,50", 1180.5},
      {"anglo mixed separators", "1,180.50", 1180.5},
      {"euro repeated grouping", "1.234.567,89", 1_234_567.89},
      {"negative euro decimal", "-1.180,50", -1180.5},
      {"currency plus grouping", "$1,180", 1180}
    ]

    for {name, input, expected} <- @accepts do
      test name do
        assert Number.extract(unquote(Macro.escape(input))) == {:ok, unquote(expected)}
      end
    end
  end

  describe "extract/1 treats blanks as zero" do
    @blanks [
      {"nil", nil},
      {"empty string", ""},
      {"whitespace only", "   "},
      {"NBSP only", " "},
      {"empty list", []},
      {"single blank element", [""]}
    ]

    for {name, input} <- @blanks do
      test name do
        assert Number.extract(unquote(Macro.escape(input))) == {:ok, 0}
      end
    end
  end

  describe "extract/1 refuses" do
    @refusals [
      {"letters", "abc"},
      {"number with letters", "12abc"},
      {"internal space", "1 180"},
      {"invalid euro grouping", "1.18,50"},
      {"multiple commas without grouping", "1,2,3"},
      {"multiple dots", "1.2.3"},
      {"accounting negative", "(250)"},
      {"double sign", "--5"},
      {"exponent notation", "1e5"},
      {"hex", "0x10"},
      {"currency only", "$"},
      {"percent only", "%"},
      {"double percent", "12%%"},
      {"boolean true", true},
      {"boolean false", false},
      {"non-option map", %{"foo" => 1}},
      {"multi-element list", [1, 2]}
    ]

    for {name, input} <- @refusals do
      test name do
        assert Number.extract(unquote(Macro.escape(input))) == :error
      end
    end
  end

  describe "extract/1 with option maps" do
    test "raw value wins" do
      assert Number.extract(%{"raw_value" => "10", "display_text" => "20"}) == {:ok, 10}
    end

    test "falls back to display text when raw is blank" do
      assert Number.extract(%{"raw_value" => nil, "display_text" => "10"}) == {:ok, 10}
    end

    test "falls back to display text when raw is junk" do
      assert Number.extract(%{"raw_value" => "abc", "display_text" => "10"}) == {:ok, 10}
    end

    test "fully blank option is blank" do
      assert Number.extract(%{"raw_value" => nil, "display_text" => nil}) == {:ok, 0}
    end

    test "blank raw with junk display is an error" do
      assert Number.extract(%{"raw_value" => "", "display_text" => "N/A"}) == :error
    end

    test "single-element list recurses" do
      assert Number.extract([%{"raw_value" => "7", "display_text" => "Seven"}]) == {:ok, 7}
    end
  end

  describe "extract_strict/1" do
    test "numbers still extract" do
      assert Number.extract_strict("1,180.50") == {:ok, 1180.5}
    end

    test "blanks are errors instead of zero" do
      assert Number.extract_strict(nil) == :error
      assert Number.extract_strict("") == :error
      assert Number.extract_strict([]) == :error
    end

    test "junk is still an error" do
      assert Number.extract_strict("abc") == :error
    end
  end
end
