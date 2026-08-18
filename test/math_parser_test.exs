defmodule AbacusTest do
  use ExUnit.Case
  doctest Abacus

  test "the lexer" do
    assert [
             {:number, _, 1},
             {:+, _},
             {:number, _, 1}
           ] = lex_term("1+1")

    assert [
             {:"(", _},
             {:number, _, 3.2},
             {:+, _},
             {:number, _, 4},
             {:")", _}
           ] = lex_term("(3.2 + 4)")
  end

  test "the lexer accepts floats with a bare dot on either side" do
    # `list_to_float("6485000.")` used to raise here — the FLOAT_END rule
    # matched the trailing dot but Erlang demands a digit after it. Prose
    # like "call 6485000." flows through parse/1, so lexing must not raise.
    assert [{:number, _, 6_485_000.0}] = lex_term("6485000.")
    assert [{:number, _, 0.5}] = lex_term(".5")
    assert [{:number, _, 2.0}, {:*, _}, {:number, _, 3}] = lex_term("2.*3")
  end

  test "parse returns an error tuple for prose, never raises" do
    assert {:error, _} = Abacus.parse("Questions? Please call 6485000. Thanks!")
  end

  describe "parse" do
    test "basic operators" do
      assert {:add, 1, 3} = parse_term("1+3")
      assert {:subtract, 50, 10} = parse_term("50- 10")
    end

    test "precedence and association" do
      assert {:add, {:add, 1, 1}, 1.2} = parse_term("1 + 1 + 1.2")

      assert {:add, {:add, 1, {:power, 3, 1}}, 1} = parse_term("1 + 3 ^ 1 + 1")

      assert {:add, {:multiply, 1, 2}, {:multiply, 3, 2}} = parse_term("1*2 + 3*2")
    end

    test "parantheses" do
      assert {:add, 1, {:add, 1, 3}} = parse_term("1 + (1 + 3)")

      assert {:add, 1, 1} = parse_term("((((((((((((((((1)))))))))))))))) + 1")
    end

    test "functions" do
      assert {:function, "sin", [90]} = parse_term("sin(90)")

      assert {:function, "max", [1, 3]} = parse_term("max(1, 3)")

      assert {:function, "cos", [{:multiply, 45, 2}]} = parse_term("cos(45 * 2)")
    end

    test "variable access" do
      assert {:access, [variable: "a"]} = parse_term("a")

      assert {:access, [variable: "a", index: 2]} = parse_term("a[2]")

      # Dots are part of the identifier, not access syntax — our keys can
      # contain periods ("referral_source.Blah").
      assert {:access, [variable: "a.b", index: {:add, 1, 2}]} = parse_term("a.b[1+2]")
    end

    test "operators tight against variables are operators, not identifier characters" do
      assert {:subtract, {:access, [variable: "ka"]}, {:access, [variable: "kb"]}} =
               parse_term("ka-kb")

      assert {:subtract, {:access, [variable: "ka"]}, {:access, [variable: "kb"]}} =
               parse_term("ka- kb")

      assert {:subtract, {:access, [variable: "ka"]}, {:access, [variable: "kb"]}} =
               parse_term("ka -kb")

      assert {:add, {:access, [variable: "ka"]}, {:access, [variable: "kb"]}} =
               parse_term("ka+kb")

      assert {:subtract, {:access, [variable: "ka.b"]}, {:access, [variable: "kc"]}} =
               parse_term("ka.b-kc")
    end

    test "modulo operator" do
      assert {:mod, 5, 2} = parse_term("5 % 2")
      assert {:mod, 5, 2} = parse_term("5%2")

      # Same precedence tier as * and /
      assert {:add, {:mod, 5, 2}, 1} = parse_term("5 % 2 + 1")
      assert {:mod, {:access, [variable: "ka"]}, {:access, [variable: "kb"]}} = parse_term("ka%kb")
    end

    test "bitwise operators" do
      assert {:not, 10} = parse_term("~10")
      assert {:and, 1, 2} = parse_term("1 & 2")
      assert {:or, 2, 3} = parse_term("2 | 3")
      assert {:xor, 3, 4} = parse_term("3 |^ 4")
      assert {:shift_left, 1, 8} = parse_term("1 << 8")
      assert {:shift_right, 32, 2} = parse_term("32 >> 2")
    end

    test "ternary operator" do
      assert {:ternary_if, {:neq, {:access, [variable: "battery"]}, 0},
              {:divide, {:subtract, {:access, [variable: "battery"]}, 1}, 253}, nil} =
               parse_term("battery != 0 ? (battery - 1) / 253 : null")
    end
  end

  describe "variables/1" do
    test "arithmetic, including tight operators" do
      {:ok, expr} = Abacus.parse("ka-kb + kc * 2")
      assert Abacus.variables(expr) == ["ka", "kb", "kc"]
    end

    test "functions and ternaries" do
      {:ok, expr} = Abacus.parse("has_any_value(ka) ? sum(kb, kc) : kd")
      assert Abacus.variables(expr) == ["ka", "kb", "kc", "kd"]
    end

    test "index access, deduplication" do
      {:ok, expr} = Abacus.parse("klist[ki] + klist[0]")
      assert Abacus.variables(expr) == ["klist", "ki"]
    end

    test "accepts a parse result directly" do
      assert Abacus.variables(Abacus.parse("ka + 1")) == ["ka"]
    end

    test "expressions with no variables" do
      {:ok, expr} = Abacus.parse("1 + 2 * 3")
      assert Abacus.variables(expr) == []
    end
  end

  def parse_term(string) do
    {:ok, result} =
      string
      |> lex_term
      |> :math_term_parser.parse()

    result
  end

  def lex_term(string) when is_binary(string) do
    string
    |> String.to_charlist()
    |> lex_term
  end

  def lex_term(string) do
    {:ok, tokens, _} = :math_term.string(string)
    tokens
  end
end
