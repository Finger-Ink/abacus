defmodule MathEvalTest do
  use ExUnit.Case
  doctest Abacus.Eval

  describe "The eval module should evaluate" do
    test "basic arithmetic" do
      assert {:ok, 1 + 2} == Abacus.eval("1 + 2")

      assert {:ok, 10 * 10} == Abacus.eval("10 * 10")

      assert {:ok, 20 * (1 + 2)} == Abacus.eval("20 * (1 + 2)")
    end

    test "function calls" do
      assert {:ok, :math.sin(90)} == Abacus.eval("sin(90)")
      assert {:ok, Float.round(512.4122, 2)} == Abacus.eval("round(512.4122, 2)")
      assert {:ok, 2} == Abacus.eval("log10(100)")
      assert {:ok, 2} == Abacus.eval("sqrt(4)")
      assert {:ok, 20.1} == Abacus.eval("abs(-20.1)")
      assert {:ok, 2} == Abacus.eval("mod(5, 3)")
      assert {:ok, 3} == Abacus.eval("count(3, 5, -3)")
      assert {:ok, 5} == Abacus.eval("sum(3, 5, -3)")
      assert {:ok, 5} == Abacus.eval("max(3, 5, -3)")
      assert {:ok, -3} == Abacus.eval("min(3, 5, -3)")
    end

    test "string equality with em dash" do
      assert {:ok, false} == Abacus.eval("do_you_smoke == \"Yes — currently\"", %{"do_you_smoke" => "No"})
    end

    test "string equality" do
      assert {:ok, false} == Abacus.eval("do_you_smoke == \"Yes, currently\"", %{"do_you_smoke" => "No"})

      assert {:ok, true} ==
               Abacus.eval("do_you_smoke == \"Yes, currently\"", %{"do_you_smoke" => "Yes, currently"})

      assert {:ok, false} == Abacus.eval("do_you_smoke == \"Yes! currently\"", %{"do_you_smoke" => "No"})
      assert {:ok, false} == Abacus.eval("do_you_smoke == \"Yes% currently\"", %{"do_you_smoke" => "No"})
      assert {:ok, false} == Abacus.eval("do_you_smoke == \"Yes' currently\"", %{"do_you_smoke" => "No"})
      assert {:ok, false} == Abacus.eval("do_you_smoke == \"Yes. currently\"", %{"do_you_smoke" => "No"})
      assert {:ok, false} == Abacus.eval("do_you_smoke == \"Yes+ currently\"", %{"do_you_smoke" => "No"})
    end

    test "includes_any function call" do
      assert {:ok, true} == Abacus.eval("includes_any([\"a\", \"b\", \"c\"], [\"a\"])")
      assert {:ok, false} == Abacus.eval("includes_any([\"a\", \"b\", \"c\"], [\"d\"])")
      assert {:ok, true} == Abacus.eval("includes_any(a, [\"a\"])", %{"a" => ["a", "b", "c"]})
      assert {:ok, true} == Abacus.eval("includes_any(a, [b])", %{"a" => ["a", "b", "c"], "b" => "b"})
    end

    test "includes_all function call" do
      assert {:ok, false} == Abacus.eval("includes_all(a, b)", %{"a" => ["a", "b", "c"], "b" => ["d"]})
      assert {:ok, true} == Abacus.eval("includes_all(a, b)", %{"a" => ["a", "b", "c"], "b" => ["b", "c"]})

      assert {:ok, true} ==
               Abacus.eval("includes_all(a, b)", %{"a" => ["a", "b"], "b" => ["a", "b"]})

      assert {:ok, false} ==
               Abacus.eval("includes_all(a, b)", %{"a" => ["a"], "b" => ["a", "b"]})
    end

    test "has_any_value function call" do
      assert {:ok, true} == Abacus.eval("has_any_value(a)", %{"a" => "Banana"})
      assert {:ok, false} == Abacus.eval("has_any_value(a)", %{"a" => ""})
    end

    test "has_no_value function call" do
      assert {:ok, false} == Abacus.eval("has_no_value(a)", %{"a" => "Banana"})
      assert {:ok, true} == Abacus.eval("has_no_value(a)", %{"a" => ""})
    end

    test "age function call" do
      assert {:ok, 41} == Abacus.eval("age(a)", %{"a" => "1984-10-03T00:00:00.000Z"})
      assert {:ok, false} == Abacus.eval("age(a) > 41", %{"a" => "1984-10-03T00:00:00.000Z"})
      assert {:ok, true} == Abacus.eval("age(a) <= 41", %{"a" => "1984-10-03T00:00:00.000Z"})
      assert {:ok, true} == Abacus.eval("age(a) < 45", %{"a" => "1984-10-03T00:00:00.000Z"})
    end

    test "error" do
      assert {:error, _} = Abacus.eval("undefined_function()")
      # This is actually OK, because we don't check for types in the max function
      # assert {:error, _} = Abacus.eval("max(3, 5, -3, false)")
      assert {:error, _} = Abacus.eval("sum(3, 5, -3, b)")
    end

    test "scoped variables" do
      assert {:ok, 8} = Abacus.eval("a + 3", %{"a" => 5})
    end

    test "factorial" do
      assert {:ok, 3_628_800} == Abacus.eval("(5 * 2)!")
    end

    # This sort of access isn't supported, so we can instead support variables with periods.
    # test "variables" do
    #   assert {:ok, 10} ==
    #            Abacus.eval("a.b.c[1]", %{
    #              "a" => %{
    #                "b" => %{
    #                  "c" => [
    #                    1,
    #                    10,
    #                    -42
    #                  ]
    #                }
    #              }
    #            })
    # end

    test "variables" do
      assert {:ok, 10} ==
               Abacus.eval("a.b.c[1]", %{
                 "a.b.c" => [
                   1,
                   10,
                   -42
                 ]
               })
    end

    test "variable in index expression" do
      assert {:ok, 10} ==
               Abacus.eval("list[a]", %{
                 "list" => [1, 2, 3, 10, 5],
                 "a" => 3
               })
    end

    test "bitwise operators" do
      use Bitwise
      assert {:ok, 1 &&& 2} == Abacus.eval("1 & 2")
      assert {:ok, 3 ||| 4} == Abacus.eval("3 | 4")
      assert {:ok, 1 ^^^ 2} == Abacus.eval("1 |^ 2")
      assert {:ok, ~~~10} == Abacus.eval("~10")
      assert {:ok, 1 <<< 8} == Abacus.eval("1 << 8")
      assert {:ok, 32 >>> 2} == Abacus.eval("32 >> 2")
    end

    test "ternary operator" do
      assert {:ok, 42} == Abacus.eval("1 == 1 ? 42 : 0")
      assert {:ok, 42} == Abacus.eval("1 == 2 ? 0 : 42")
    end

    test "reserved words" do
      assert {:ok, true} == Abacus.eval("true")
      assert {:ok, false} == Abacus.eval("false")
      assert {:ok, nil} == Abacus.eval("null")
    end

    test "comparison" do
      assert {:ok, true} = Abacus.eval("42 > 10")
      assert {:ok, true} = Abacus.eval("42 >= 10")
      assert {:ok, false} = Abacus.eval("42 < 10")
      assert {:ok, true} = Abacus.eval("10 < 42")
      assert {:ok, false} = Abacus.eval("42 == 10")
      assert {:ok, true} = Abacus.eval("42 != 10")
      assert {:ok, false} = Abacus.eval("10 != 10")
      assert {:ok, true} = Abacus.eval(~s["a" == "a"])
      assert {:ok, true} = Abacus.eval(~s["a" == a], %{"a" => "a"})
      assert {:ok, true} = Abacus.eval("\"a\\\"b\" == a", %{"a" => "a\"b"})
      assert {:ok, true} = Abacus.eval("a == b", %{"a" => :foo, "b" => "foo"})
      assert {:ok, true} = Abacus.eval("a == b", %{"a" => "foo", "b" => :foo})
      assert {:ok, true} = Abacus.eval("a == b", %{"a" => :foo, "b" => :foo})
      assert {:ok, true} = Abacus.eval("a == b", %{"a" => "foo", "b" => "foo"})
      assert {:ok, true} = Abacus.eval("\"foo\" == b", %{"b" => :foo})
      assert {:ok, false} = Abacus.eval("a == b", %{"a" => :foo, "b" => :bar})
    end

    test "invalid boolean arithmetic" do
      assert {:error, _} = Abacus.eval("false + 1")
    end

    test "unexpected token" do
      assert {:error, _} = Abacus.eval("1 + )")
    end
  end

  describe "operator and operand parity with the JS engine" do
    test "tight minus between variables is subtraction" do
      assert {:ok, 250} == Abacus.eval("ka-kb", %{"ka" => "1180", "kb" => "930"})
    end

    test "modulo" do
      assert {:ok, 1} == Abacus.eval("5 % 2")
      assert {:ok, 1.5} == Abacus.eval("5.5 % 2")
      # JS remainder semantics: the result takes the dividend's sign
      assert {:ok, -1} == Abacus.eval("-5 % 2")
    end

    test "division by zero is unevaluable, not a crash" do
      assert {:error, :einval} == Abacus.eval("1 / 0")
      assert {:error, :einval} == Abacus.eval("a / b", %{"a" => "1180", "b" => "0"})
      assert {:error, :einval} == Abacus.eval("a / b", %{"a" => "1180", "b" => ""})
      assert {:error, :einval} == Abacus.eval("5 % 0")
      assert {:error, :einval} == Abacus.eval("mod(5, 0)")
      assert {:error, :einval} == Abacus.eval("0 ^ -1")
    end

    test "out-of-domain maths is unevaluable, not a crash" do
      assert {:error, :einval} == Abacus.eval("sqrt(-1)")
      assert {:error, :einval} == Abacus.eval("log10(0)")
    end

    test "operands coerce: whitespace, blanks, currency, percent, decimal commas" do
      assert {:ok, 250} == Abacus.eval("a - b", %{"a" => "1180 ", "b" => " 930"})
      assert {:ok, 1180} == Abacus.eval("a - b", %{"a" => "1180", "b" => ""})
      assert {:ok, 1180} == Abacus.eval("a - b", %{"a" => "1180", "b" => nil})
      assert {:ok, 250} == Abacus.eval("a - b", %{"a" => "$1,180", "b" => "930 %"})
      assert {:ok, 1108} == Abacus.eval("a - b", %{"a" => "1.180,50", "b" => "72,5"})
    end

    test "results collapse to integers when whole, like JS numbers" do
      assert {:ok, 5} == Abacus.eval("10 / 2")
      assert {:ok, 5} == Abacus.eval("2.5 + 2.5")
      assert {:ok, 1024} == Abacus.eval("2 ^ 10")
    end

    test "junk operands are unevaluable" do
      assert {:error, :einval} == Abacus.eval("a - b", %{"a" => "abc", "b" => "930"})
    end

    test "ordering comparisons coerce numerically" do
      assert {:ok, true} == Abacus.eval("a > b", %{"a" => "1180", "b" => "930"})
      assert {:ok, false} == Abacus.eval("a > b", %{"a" => nil, "b" => "930"})
      assert {:ok, true} == Abacus.eval("a < b", %{"a" => "", "b" => "1"})
      # Both non-numeric strings: lexicographic, as JS compares two strings
      assert {:ok, true} == Abacus.eval("a < b", %{"a" => "apple", "b" => "banana"})
      # Junk string against a number: refused outright
      assert {:ok, false} == Abacus.eval("a > 5", %{"a" => "abc"})
      assert {:ok, false} == Abacus.eval("a < 5", %{"a" => "abc"})
    end

    test "option maps coerce raw value first, display text second" do
      option = %{"raw_value" => "10", "display_text" => "Ten"}
      assert {:ok, 15} == Abacus.eval("a + 5", %{"a" => option})

      display_only = %{"raw_value" => nil, "display_text" => "10"}
      assert {:ok, 15} == Abacus.eval("a + 5", %{"a" => display_only})
    end

    test "raw_num and display_num" do
      option = %{"raw_value" => "7", "display_text" => "Seven"}
      assert {:ok, 7} == Abacus.eval("raw_num(a)", %{"a" => option})
      assert {:ok, nil} == Abacus.eval("display_num(a)", %{"a" => option})
      assert {:ok, 0} == Abacus.eval("raw_num(a)", %{"a" => ""})
      assert {:ok, 50} == Abacus.eval("display_num(a)", %{"a" => "50%"})
    end

    test "display function mirrors the JS engine" do
      option = %{"display_text" => "Mild", "raw_value" => "1"}
      assert {:ok, "Mild"} == Abacus.eval("display(a)", %{"a" => option})
      assert {:ok, "Mild"} == Abacus.eval("display(a)", %{"a" => [option]})

      assert {:ok, ["Mild", "Bad"]} ==
               Abacus.eval("display(a)", %{
                 "a" => [option, %{"display_text" => "Bad", "raw_value" => "2"}]
               })

      assert {:ok, "text"} == Abacus.eval("display(a)", %{"a" => "text"})
      assert {:ok, nil} == Abacus.eval("display(a)", %{"a" => nil})
    end

    test "format round-trips strings and modulo" do
      assert {:ok, ~s[a == "Yes"]} == Abacus.format(~s[a=="Yes"])
      assert {:ok, "5 % 2"} == Abacus.format("5%2")
      assert {:ok, ~s[a == "sa\\"id"]} == Abacus.format("a == \"sa\\\"id\"")
    end

    test "sum/average/min/max drop blanks but keep zeros" do
      assert {:ok, 4} == Abacus.eval("sum(a, b, c)", %{"a" => "1", "b" => "", "c" => "3"})
      assert {:ok, 2} == Abacus.eval("average(a, b, c)", %{"a" => "1", "b" => "", "c" => "3"})
      assert {:ok, 0} == Abacus.eval("min(a, b)", %{"a" => "0", "b" => "5"})
      assert {:ok, 3} == Abacus.eval("sum(a, b)", %{"a" => "$1", "b" => "2,0"})
    end
  end

  describe "average, max, min with empty/non-numeric data" do
    test "average returns error for empty list" do
      assert {:error, :einval} == Abacus.eval("average(a)", %{"a" => []})
    end

    test "max returns error for empty list" do
      assert {:error, :einval} == Abacus.eval("max(a)", %{"a" => []})
    end

    test "min returns error for empty list" do
      assert {:error, :einval} == Abacus.eval("min(a)", %{"a" => []})
    end

    test "average returns error for non-numeric values" do
      assert {:error, :einval} == Abacus.eval("average(a, b)", %{"a" => "foo", "b" => "bar"})
    end

    test "max returns error for non-numeric values" do
      assert {:error, :einval} == Abacus.eval("max(a, b)", %{"a" => "foo", "b" => "bar"})
    end

    test "min returns error for non-numeric values" do
      assert {:error, :einval} == Abacus.eval("min(a, b)", %{"a" => "foo", "b" => "bar"})
    end

    test "average still works with valid numbers" do
      assert {:ok, 2} == Abacus.eval("average(1, 2, 3)")
    end

    test "max still works with valid numbers" do
      assert {:ok, 3} == Abacus.eval("max(1, 2, 3)")
    end

    test "min still works with valid numbers" do
      assert {:ok, 1} == Abacus.eval("min(1, 2, 3)")
    end
  end

  describe "Float functions (floor, ceil, round)" do
    test "floor with integer input" do
      # Integer should be converted to float
      assert {:ok, 33} == Abacus.eval("floor(33)")
      assert {:ok, -5} == Abacus.eval("floor(-5)")
      assert {:ok, 0} == Abacus.eval("floor(0)")
    end

    test "floor with float input" do
      assert {:ok, 33} == Abacus.eval("floor(33.7)")
      assert {:ok, -6} == Abacus.eval("floor(-5.3)")
      assert {:ok, 0} == Abacus.eval("floor(0.9)")
    end

    test "floor with precision parameter (integer precision)" do
      assert {:ok, Float.floor(33.789, 1)} == Abacus.eval("floor(33.789, 1)")
      assert {:ok, Float.floor(33.789, 2)} == Abacus.eval("floor(33.789, 2)")
      assert {:ok, Float.floor(-5.678, 1)} == Abacus.eval("floor(-5.678, 1)")
    end

    test "floor with precision parameter (float precision - should truncate)" do
      # Precision should be truncated to integer
      assert {:ok, Float.floor(33.789, 1)} == Abacus.eval("floor(33.789, 1.7)")
      assert {:ok, Float.floor(33.789, 2)} == Abacus.eval("floor(33.789, 2.9)")
      assert {:ok, Float.floor(33.789, 0)} == Abacus.eval("floor(33.789, 0.5)")
    end

    test "floor with string input" do
      assert {:ok, 33} == Abacus.eval("floor(\"33\")")
      assert {:ok, 33} == Abacus.eval("floor(\"33.7\")")
      assert {:ok, -6} == Abacus.eval("floor(\"-5.3\")")
    end

    test "ceil with integer input" do
      # Integer should be converted to float
      assert {:ok, 33} == Abacus.eval("ceil(33)")
      assert {:ok, -5} == Abacus.eval("ceil(-5)")
      assert {:ok, 0} == Abacus.eval("ceil(0)")
    end

    test "ceil with float input" do
      assert {:ok, 34} == Abacus.eval("ceil(33.1)")
      assert {:ok, -5} == Abacus.eval("ceil(-5.9)")
      assert {:ok, 1} == Abacus.eval("ceil(0.1)")
    end

    test "ceil with precision parameter (integer precision)" do
      assert {:ok, Float.ceil(33.789, 1)} == Abacus.eval("ceil(33.789, 1)")
      assert {:ok, Float.ceil(33.789, 2)} == Abacus.eval("ceil(33.789, 2)")
      assert {:ok, Float.ceil(-5.678, 1)} == Abacus.eval("ceil(-5.678, 1)")
    end

    test "ceil with precision parameter (float precision - should truncate)" do
      # Precision should be truncated to integer
      assert {:ok, Float.ceil(33.789, 1)} == Abacus.eval("ceil(33.789, 1.7)")
      assert {:ok, Float.ceil(33.789, 2)} == Abacus.eval("ceil(33.789, 2.9)")
      assert {:ok, Float.ceil(33.789, 0)} == Abacus.eval("ceil(33.789, 0.5)")
    end

    test "ceil with string input" do
      assert {:ok, 33} == Abacus.eval("ceil(\"33\")")
      assert {:ok, 34} == Abacus.eval("ceil(\"33.1\")")
      assert {:ok, -5} == Abacus.eval("ceil(\"-5.9\")")
    end

    test "round with integer input" do
      # Integer should be converted to float
      assert {:ok, 33} == Abacus.eval("round(33)")
      assert {:ok, -5} == Abacus.eval("round(-5)")
      assert {:ok, 0} == Abacus.eval("round(0)")
    end

    test "round with float input" do
      assert {:ok, 34} == Abacus.eval("round(33.5)")
      assert {:ok, 33} == Abacus.eval("round(33.4)")
      assert {:ok, -5} == Abacus.eval("round(-5.4)")
      assert {:ok, -6} == Abacus.eval("round(-5.5)")
    end

    test "round with precision parameter (integer precision)" do
      assert {:ok, Float.round(33.789, 1)} == Abacus.eval("round(33.789, 1)")
      assert {:ok, Float.round(33.789, 2)} == Abacus.eval("round(33.789, 2)")
      assert {:ok, Float.round(-5.678, 1)} == Abacus.eval("round(-5.678, 1)")
    end

    test "round with precision parameter (float precision - should truncate)" do
      # Precision should be truncated to integer
      assert {:ok, Float.round(33.789, 1)} == Abacus.eval("round(33.789, 1.7)")
      assert {:ok, Float.round(33.789, 2)} == Abacus.eval("round(33.789, 2.9)")
      assert {:ok, Float.round(33.789, 0)} == Abacus.eval("round(33.789, 0.5)")
    end

    test "round with string input" do
      assert {:ok, 33} == Abacus.eval("round(\"33\")")
      assert {:ok, 34} == Abacus.eval("round(\"33.5\")")
      assert {:ok, -5} == Abacus.eval("round(\"-5.4\")")
    end

    test "roundTo and round_to aliases" do
      assert {:ok, 34} == Abacus.eval("roundTo(33.5)")
      assert {:ok, 34} == Abacus.eval("round_to(33.5)")
      assert {:ok, Float.round(33.789, 2)} == Abacus.eval("roundTo(33.789, 2)")
      assert {:ok, Float.round(33.789, 2)} == Abacus.eval("round_to(33.789, 2)")
      assert {:ok, Float.round(33.789, 1)} == Abacus.eval("roundTo(33.789, 1.7)")
      assert {:ok, Float.round(33.789, 1)} == Abacus.eval("round_to(33.789, 1.7)")
    end

    test "Float functions with variables" do
      assert {:ok, 33} == Abacus.eval("floor(a)", %{"a" => 33.7})
      assert {:ok, 34} == Abacus.eval("ceil(a)", %{"a" => 33.1})
      assert {:ok, 34} == Abacus.eval("round(a)", %{"a" => 33.5})
      assert {:ok, Float.floor(33.789, 2)} == Abacus.eval("floor(a, 2)", %{"a" => 33.789})
      assert {:ok, Float.floor(33.789, 2)} == Abacus.eval("floor(a, b)", %{"a" => 33.789, "b" => 2.7})
    end

    test "Float functions error cases" do
      assert {:error, _} = Abacus.eval("floor()")
      assert {:error, _} = Abacus.eval("ceil()")
      assert {:error, _} = Abacus.eval("round()")
      assert {:error, _} = Abacus.eval("floor(\"invalid\")")
      assert {:error, _} = Abacus.eval("ceil(\"invalid\")")
      assert {:error, _} = Abacus.eval("round(\"invalid\")")
    end
  end
end
