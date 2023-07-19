defmodule Abacus.Eval do
  @moduledoc """
  Function definitions on how to evaluate a syntax tree.

  You usually don't need to call `eval/2` yourself, use `Abacus.eval/2` instead.
  """

  import Bitwise
  alias Abacus.Util

  @spec eval(expr :: tuple | number, scope :: map) ::
          {:ok, result :: number} | {:ok, boolean} | {:ok, nil} | {:error, term}

  # BASIC ARITHMETIC

  def eval({:add, a, b}, _)
      when is_number(a) and is_number(b),
      do: {:ok, a + b}

  def eval({:subtract, a, b}, _)
      when is_number(a) and is_number(b),
      do: {:ok, a - b}

  def eval({:divide, a, b}, _)
      when is_number(a) and is_number(b),
      do: {:ok, a / b}

  def eval({:multiply, a, b}, _)
      when is_number(a) and is_number(b),
      do: {:ok, a * b}

  # OTHER OPERATORS

  def eval({:power, a, b}, _)
      when is_number(a) and is_number(b),
      do: {:ok, :math.pow(a, b)}

  def eval({:factorial, a}, _)
      when is_number(a),
      do: {:ok, Util.factorial(a)}

  # COMPARISION

  def eval({:eq, a, b}, _),
    do: {:ok, equals(a, b)}

  def eval({:neq, a, b}, _),
    do: {:ok, not equals(a, b)}

  def eval({:gt, a, b}, _),
    do: {:ok, greater_than(a, b)}

  def eval({:gte, a, b}, _),
    do: {:ok, greater_than_or_equal_to(a, b)}

  def eval({:lt, a, b}, _),
    do: {:ok, less_than(a, b)}

  def eval({:lte, a, b}, _),
    do: {:ok, less_than_or_equal_to(a, b)}

  # LOGICAL COMPARISION

  def eval({:logical_and, a, b}, _)
      when is_boolean(a) and is_boolean(b),
      do: {:ok, a && b}

  def eval({:logical_or, a, b}, _)
      when is_boolean(a) and is_boolean(b),
      do: {:ok, a || b}

  def eval({:logical_not, a}, _)
      when is_boolean(a),
      do: {:ok, not a}

  def eval({:ternary_if, condition, if_true, if_false}, _) do
    if condition do
      {:ok, if_true}
    else
      {:ok, if_false}
    end
  end

  # FUNCTIONS

  def eval({:function, "sin", [a]}, _)
      when is_number(a),
      do: {:ok, :math.sin(a)}

  def eval({:function, "cos", [a]}, _)
      when is_number(a),
      do: {:ok, :math.cos(a)}

  def eval({:function, "tan", [a]}, _)
      when is_number(a),
      do: {:ok, :math.tan(a)}

  def eval({:function, "floor", [a]}, _)
      when is_number(a),
      do: {:ok, Float.floor(a)}

  def eval({:function, "floor", [a, precision]}, _)
      when is_number(a) and is_number(precision),
      do: {:ok, Float.floor(a, precision)}

  def eval({:function, "ceil", [a]}, _)
      when is_number(a),
      do: {:ok, Float.ceil(a)}

  def eval({:function, "ceil", [a, precision]}, _)
      when is_number(a) and is_number(precision),
      do: {:ok, Float.ceil(a, precision)}

  def eval({:function, "round", [a]}, _)
      when is_number(a),
      do: {:ok, Float.round(a)}

  def eval({:function, "round", [a, precision]}, _)
      when is_number(a) and is_number(precision),
      do: {:ok, Float.round(a, precision)}

  def eval({:function, "log10", [a]}, _)
      when is_number(a),
      do: {:ok, :math.log10(a)}

  def eval({:function, "sqrt", [a]}, _)
      when is_number(a),
      do: {:ok, :math.sqrt(a)}

  def eval({:function, "abs", [a]}, _)
      when is_number(a),
      do: {:ok, Kernel.abs(a)}

  def eval({:function, "mod", [a, b]}, _)
      when is_number(a),
      do: {:ok, :math.fmod(a, b)}

  def eval({:function, "count", data_set}, _scope) do
    with false <- Enum.any?(data_set, fn x -> !is_number(x) end) do
      {:ok, Enum.count(data_set)}
    else
      _ -> {:error, :einval}
    end
  end

  ## ------------------
  ## Normalisation for different data types being compared
  ## ------------------

  # > >= < <=
  defp greater_than(a, b), do: compare(&>/2, a, b)
  defp greater_than_or_equal_to(a, b), do: compare(&>=/2, a, b)
  defp less_than(a, b), do: compare(&</2, a, b)
  defp less_than_or_equal_to(a, b), do: compare(&<=/2, a, b)

  defp string_compare_number(op, text, num) when is_binary(text) and is_number(num) do
    case force_number(text) do
      {:error, :einval} -> {:error, :einval}
      forced_num -> apply(op, [forced_num, num])
    end
  end

  defp compare(op, text, num) when is_binary(text) and is_number(num),
    do: string_compare_number(op, text, num)

  defp compare(op, num, text) when is_binary(text) and is_number(num),
    do: string_compare_number(op, text, num)

  defp compare(op, a, b), do: apply(op, [a, b])

  # Equals
  defp string_equals_number(text, num) when is_binary(text) and is_number(num) do
    case force_number(text) do
      {:error, :einval} -> text == "#{num}"
      forced_num -> forced_num == num
    end
  end

  defp equals(text, num) when is_binary(text) and is_number(num),
    do: string_equals_number(text, num)

  defp equals(num, text) when is_binary(text) and is_number(num),
    do: string_equals_number(text, num)

  defp equals(%{"display_text" => text}, str) when is_binary(str), do: str == text
  defp equals(str, %{"display_text" => text}) when is_binary(str), do: str == text

  defp equals(
         %{"display_text" => text1, "raw_value" => value1},
         %{"display_text" => text2, "raw_value" => value2}
       ),
       do: text1 == text2 and value1 == value2

  defp equals(str, atom) when is_binary(str) and is_atom(atom), do: str == Atom.to_string(atom)
  defp equals(atom, str) when is_binary(str) and is_atom(atom), do: str == Atom.to_string(atom)
  defp equals(a, b), do: a == b

  ## ------------------
  ## Custom maths
  ## ------------------

  # This used to be a standard function but I've changed it so that it can
  # take any type of parameter we throw at it.
  def eval({:function, "sum", data_set}, _scope) do
    data_set = data_set |> get_as_flat_numbers_try_raw_first()

    with false <- Enum.any?(data_set, fn x -> !is_number(x) end) do
      result = Enum.sum(data_set) |> integer_if_possible()
      {:ok, result}
    else
      _ -> {:error, :einval}
    end
  end

  def eval({:function, "average", data_set}, _scope) do
    data_set = data_set |> get_as_flat_numbers_try_raw_first()

    with false <- Enum.any?(data_set, fn x -> !is_number(x) end) do
      result = (Enum.sum(data_set) / Enum.count(data_set)) |> integer_if_possible()
      {:ok, result}
    else
      _ -> {:error, :einval}
    end
  end

  def eval({:function, "max", data_set}, _scope) do
    data_set = data_set |> get_as_flat_numbers_try_raw_first()

    with false <- Enum.any?(data_set, fn x -> !is_number(x) end) do
      {:ok, Enum.max(data_set)}
    else
      _ -> {:error, :einval}
    end
  end

  def eval({:function, "min", data_set}, _scope) do
    data_set = data_set |> get_as_flat_numbers_try_raw_first()

    with false <- Enum.any?(data_set, fn x -> !is_number(x) end) do
      {:ok, Enum.min(data_set)}
    else
      _ -> {:error, :einval}
    end
  end

  ## ------------------
  ## Custom functions
  ## ------------------

  def eval({:function, "raw", [maybe_value]}, _scope) do
    cond do
      is_list(maybe_value) -> {:ok, extract_raw_value(maybe_value)}
      is_map(maybe_value) -> {:ok, extract_raw_value(maybe_value)}
      is_binary(maybe_value) -> {:ok, maybe_value}
      is_number(maybe_value) -> {:ok, maybe_value}
      true -> {:error, :einval}
    end
  end

  def eval({:function, "value", [maybe_value]}, scope),
    do: eval({:function, "raw", [maybe_value]}, scope)

  def eval({:function, "includes_any", [search_in | search_for]}, _scope) do
    search_in = ensure_list(search_in)

    cond do
      search_in |> Enum.at(0) == nil ->
        {:ok, false}

      is_list(search_for) ->
        {:ok, Enum.any?(search_for, fn x -> x |> exists_in_options?(search_in) end)}

      is_binary(search_for) or is_number(search_for) ->
        {:ok, search_for |> exists_in_options?(search_in)}

      true ->
        {:error, :einval}
    end
  end

  def eval({:function, "includes_all", [search_in | search_for]}, _scope) do
    search_in = ensure_list(search_in)

    cond do
      search_in |> Enum.at(0) == nil ->
        {:ok, false}

      is_list(search_for) ->
        {:ok, Enum.all?(search_for, fn x -> x |> exists_in_options?(search_in) end)}

      is_binary(search_for) or is_number(search_for) ->
        {:ok, search_for |> exists_in_options?(search_in)}

      true ->
        {:error, :einval}
    end
  end

  def eval({:function, "has_any_value", [maybe_value]}, _scope) do
    cond do
      is_list(maybe_value) -> {:ok, maybe_value != []}
      is_binary(maybe_value) -> {:ok, maybe_value != ""}
      true -> {:error, :einval}
    end
  end

  def eval({:function, "has_no_value", [maybe_value]}, _scope) do
    cond do
      is_list(maybe_value) -> {:ok, maybe_value == []}
      is_binary(maybe_value) -> {:ok, maybe_value == ""}
      true -> {:error, :einval}
    end
  end

  def eval({:function, "age", [dt]}, _scope) do
    case dt do
      nil ->
        {:error, :einval}

      <<date_string::binary-size(10)>> <> _ ->
        {:ok, date} = NaiveDateTime.from_iso8601("#{date_string}T00:00:00")
        diff_seconds = NaiveDateTime.diff(NaiveDateTime.utc_now(), date)
        {:ok, (diff_seconds / 31_536_000) |> Kernel.trunc()}

      _ ->
        {:error, :einval}
    end
  end

  def eval({:function, "display_num", [maybe_value]}, _scope) do
    cond do
      is_list(maybe_value) -> {:ok, extract_display_text(maybe_value) |> force_number()}
      is_map(maybe_value) -> {:ok, extract_display_text(maybe_value) |> force_number()}
      is_binary(maybe_value) -> {:ok, maybe_value |> force_number()}
      is_number(maybe_value) -> {:ok, maybe_value |> force_number()}
      true -> {:error, :einval}
    end
  end

  def eval({:function, "raw_num", [maybe_value]}, _scope) do
    cond do
      is_list(maybe_value) -> {:ok, extract_raw_value(maybe_value) |> force_number()}
      is_map(maybe_value) -> {:ok, extract_raw_value(maybe_value) |> force_number()}
      is_binary(maybe_value) -> {:ok, maybe_value |> force_number()}
      is_number(maybe_value) -> {:ok, maybe_value |> force_number()}
      true -> {:error, :einval}
    end
  end

  # IDENTITY

  def eval(number, _)
      when is_number(number),
      do: {:ok, number}

  def eval(reserved, _)
      when reserved in [nil, true, false],
      do: {:ok, reserved}

  def eval(string, _)
      when is_binary(string),
      do: {:ok, string}

  # ACCESS

  def eval({:access, _} = expr, scope) do
    eval(expr, scope, scope)
  end

  # BINARY OPERATORS

  def eval({:not, expr}, _)
      when is_number(expr),
      do: {:ok, bnot(expr)}

  def eval({:and, a, b}, _)
      when is_number(a) and is_number(b),
      do: {:ok, band(a, b)}

  def eval({:or, a, b}, _)
      when is_number(a) and is_number(b),
      do: {:ok, bor(a, b)}

  def eval({:xor, a, b}, _)
      when is_number(a) and is_number(b),
      do: {:ok, bxor(a, b)}

  def eval({:shift_right, a, b}, _)
      when is_number(a) and is_number(b),
      do: {:ok, a >>> b}

  def eval({:shift_left, a, b}, _)
      when is_number(a) and is_number(b),
      do: {:ok, a <<< b}

  # CATCH-ALL
  # !!! write new evaluations above this definition !!!
  def eval(_expr, _scope), do: {:error, :einval}

  # SPECIAL HANDLING FOR ACCESS

  import Abacus.Tree, only: [reduce: 2]

  defp eval({:access, [{:variable, name} | rest]}, scope, root) do
    case Map.get(scope, name, nil) do
      nil ->
        {:error, :einkey}

      value ->
        eval({:access, rest}, value, root)
    end
  end

  defp eval({:access, [{:index, index} | rest]}, scope, root) do
    {:ok, index} = reduce(index, &eval(&1, root))

    case Enum.at(scope, index, nil) do
      nil ->
        {:error, :einkey}

      value ->
        eval({:access, rest}, value, root)
    end
  end

  defp eval({:access, []}, value, _root), do: {:ok, value}

  defp ensure_list(list) when is_list(list), do: list
  defp ensure_list(other), do: [other]

  defp extract_raw_value(list) when is_list(list),
    do: list |> Enum.map(fn v -> extract_raw_value(v) end)

  defp extract_raw_value(%{"raw_value" => value}), do: value
  defp extract_raw_value(_), do: nil

  defp extract_display_text(list) when is_list(list),
    do: list |> Enum.map(fn v -> extract_display_text(v) end)

  defp extract_display_text(%{"display_text" => value}), do: value
  defp extract_display_text(_), do: nil

  defp exists_in_options?(%{"display_text" => _, "raw_value" => _} = option, options) do
    options
    |> optionify()
    |> contains?(option)
  end

  defp exists_in_options?(option, options) when is_binary(option) or is_number(option) do
    options
    |> normalise()
    |> contains?(option)
  end

  defp optionify(options) when is_list(options), do: options |> Enum.map(&optionify_option/1)

  defp optionify_option(%{"display_text" => _, "raw_value" => _} = option), do: option

  defp optionify_option(other) when is_binary(other),
    do: %{"display_text" => other, "raw_value" => other}

  defp optionify_option(_), do: nil

  defp normalise(options) when is_list(options), do: options |> Enum.map(&normalise_option/1)

  defp normalise_option(%{"display_text" => text}), do: text
  defp normalise_option(other), do: other

  defp contains?(options, %{"display_text" => _, "raw_value" => _} = option),
    do: Enum.member?(options, option)

  defp contains?(options, string), do: Enum.member?(options, string)

  ## ------------------
  ## Maths helpers
  ## ------------------

  def get_as_flat_numbers_try_raw_first(maybe_value) when is_list(maybe_value) do
    maybe_value
    |> Enum.map(fn
      val when is_list(val) -> get_as_flat_numbers_try_raw_first(val)
      val -> get_any_number_or_null(val)
    end)
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
  end

  def get_as_flat_numbers_try_raw_first(maybe_value),
    do: [get_any_number_or_null(maybe_value)] |> Enum.reject(&is_nil/1)

  def get_any_number_or_null(%{"raw_value" => raw_value, "display_text" => display_text}),
    do: force_number_or_nil(raw_value) || force_number_or_nil(display_text)

  def get_any_number_or_null(maybe_value), do: force_number_or_nil(maybe_value)

  defp force_number(list) when is_list(list) do
    {:error, :einval}
  end

  defp force_number(string) when is_binary(string) do
    # Our parsing specifically rejects anything that can't parse into
    # floats or ints without any "left-overs".
    if String.contains?(string, ".") do
      case Float.parse(string) do
        {num, ""} -> num
        _ -> {:error, :einval}
      end
    else
      case Integer.parse(string) do
        {num, ""} -> num
        _ -> {:error, :einval}
      end
    end
  end

  defp force_number(num) when is_number(num), do: num
  defp force_number(_), do: {:error, :einval}

  defp force_number_or_nil(num) do
    with {:error, :einval} <- force_number(num) do
      nil
    else
      num -> num
    end
  end

  defp integer_if_possible(int) when is_integer(int), do: int

  defp integer_if_possible(float) when is_float(float) do
    truncated = trunc(float)
    if truncated == float, do: truncated, else: float
  end
end
