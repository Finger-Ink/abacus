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

  def eval({:add, a, b}, _) do
    case {to_number(a), to_number(b)} do
      {{:ok, num_a}, {:ok, num_b}} -> {:ok, num_a + num_b}
      _ -> {:error, :einval}
    end
  end

  def eval({:subtract, a, b}, _) do
    case {to_number(a), to_number(b)} do
      {{:ok, num_a}, {:ok, num_b}} -> {:ok, num_a - num_b}
      _ -> {:error, :einval}
    end
  end

  def eval({:divide, a, b}, _) do
    case {to_number(a), to_number(b)} do
      {{:ok, num_a}, {:ok, num_b}} -> {:ok, num_a / num_b}
      _ -> {:error, :einval}
    end
  end

  def eval({:multiply, a, b}, _) do
    case {to_number(a), to_number(b)} do
      {{:ok, num_a}, {:ok, num_b}} -> {:ok, num_a * num_b}
      _ -> {:error, :einval}
    end
  end

  # OTHER OPERATORS

  def eval({:power, a, b}, _) do
    case {to_number(a), to_number(b)} do
      {{:ok, num_a}, {:ok, num_b}} -> {:ok, :math.pow(num_a, num_b)}
      _ -> {:error, :einval}
    end
  end

  # We nope out of this bad boy
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

  def eval({:function, "sin", [a]}, _) do
    case to_number(a) do
      {:ok, num_a} -> {:ok, :math.sin(num_a)}
      _ -> {:error, :einval}
    end
  end

  def eval({:function, "cos", [a]}, _) do
    case to_number(a) do
      {:ok, num_a} -> {:ok, :math.cos(num_a)}
      _ -> {:error, :einval}
    end
  end

  def eval({:function, "tan", [a]}, _) do
    case to_number(a) do
      {:ok, num_a} -> {:ok, :math.tan(num_a)}
      _ -> {:error, :einval}
    end
  end

  # Note: we now send the result to trunc() so we drop the decimals
  def eval({:function, "floor", [a]}, _) do
    case to_float(a) do
      {:ok, num_a} -> {:ok, Float.floor(num_a) |> trunc()}
      _ -> {:error, :einval}
    end
  end

  def eval({:function, "floor", [a, precision]}, _) do
    case {to_float(a), to_integer(precision)} do
      {{:ok, num_a}, {:ok, num_precision}} -> {:ok, Float.floor(num_a, num_precision)}
      _ -> {:error, :einval}
    end
  end

  # Note: we now send the result to trunc() so we drop the decimals
  def eval({:function, "ceil", [a]}, _) do
    case to_float(a) do
      {:ok, num_a} -> {:ok, Float.ceil(num_a) |> trunc()}
      _ -> {:error, :einval}
    end
  end

  def eval({:function, "ceil", [a, precision]}, _) do
    case {to_float(a), to_integer(precision)} do
      {{:ok, num_a}, {:ok, num_precision}} -> {:ok, Float.ceil(num_a, num_precision)}
      _ -> {:error, :einval}
    end
  end

  # This is how we define round in our JS expressions — both roundTo and round_to
  def eval({:function, func, [a]}, other) when func in ["roundTo", "round_to"],
    do: eval({:function, "round", [a]}, other)

  def eval({:function, func, [a, precision]}, other) when func in ["roundTo", "round_to"],
    do: eval({:function, "round", [a, precision]}, other)

  # Note: we now send the result to trunc() so we drop the decimals
  def eval({:function, "round", [a]}, _) do
    case to_float(a) do
      {:ok, num_a} -> {:ok, Float.round(num_a) |> trunc()}
      _ -> {:error, :einval}
    end
  end

  def eval({:function, "round", [a, precision]}, _) do
    case {to_float(a), to_integer(precision)} do
      {{:ok, num_a}, {:ok, num_precision}} -> {:ok, Float.round(num_a, num_precision)}
      _ -> {:error, :einval}
    end
  end

  def eval({:function, "log10", [a]}, _) do
    case to_number(a) do
      {:ok, num_a} -> {:ok, :math.log10(num_a)}
      _ -> {:error, :einval}
    end
  end

  def eval({:function, "sqrt", [a]}, _) do
    case to_number(a) do
      {:ok, num_a} -> {:ok, :math.sqrt(num_a)}
      _ -> {:error, :einval}
    end
  end

  def eval({:function, "abs", [a]}, _) do
    case to_number(a) do
      {:ok, num_a} -> {:ok, Kernel.abs(num_a)}
      _ -> {:error, :einval}
    end
  end

  def eval({:function, "mod", [a, b]}, _) do
    case {to_number(a), to_number(b)} do
      {{:ok, num_a}, {:ok, num_b}} -> {:ok, :math.fmod(num_a, num_b)}
      _ -> {:error, :einval}
    end
  end

  ## ------------------
  ## Custom maths
  ## ------------------

  # This used to be a standard function but I've changed it so that it can
  # take any type of parameter we throw at it.
  def eval({:function, "count", data_set}, _scope) do
    data_set = data_set |> get_as_flat_list()
    result = Enum.count(data_set)
    {:ok, result}
  end

  # This also used to be a standard function but I've changed it so that it can
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

  # Custom equals and not equals for javascript
  def eval({:function, "equals", [a | [b]]}, _scope), do: {:ok, equals(a, b)}
  def eval({:function, "not_equals", [a | [b]]}, _scope), do: {:ok, not equals(a, b)}

  def eval({:function, "raw", [maybe_value]}, _scope) do
    cond do
      is_nil(maybe_value) -> {:ok, nil}
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

  def eval({:function, "does_not_include", [search_in | search_for]}, _scope) do
    search_in = ensure_list(search_in)

    cond do
      search_in |> Enum.at(0) == nil ->
        {:ok, true}

      is_list(search_for) ->
        {:ok, !Enum.any?(search_for, fn x -> x |> exists_in_options?(search_in) end)}

      is_binary(search_for) or is_number(search_for) ->
        {:ok, !(search_for |> exists_in_options?(search_in))}

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
      is_nil(maybe_value) -> {:ok, false}
      is_map(maybe_value) -> {:ok, true}
      is_list(maybe_value) -> {:ok, maybe_value != []}
      is_binary(maybe_value) -> {:ok, maybe_value != ""}
      true -> {:error, :einval}
    end
  end

  def eval({:function, "has_no_value", [maybe_value]}, _scope) do
    cond do
      is_nil(maybe_value) -> {:ok, true}
      is_map(maybe_value) -> {:ok, false}
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

  def eval({:not, expr}, _) do
    case to_number(expr) do
      {:ok, num_expr} -> {:ok, bnot(num_expr)}
      _ -> {:error, :einval}
    end
  end

  def eval({:and, a, b}, _) do
    case {to_number(a), to_number(b)} do
      {{:ok, num_a}, {:ok, num_b}} -> {:ok, band(num_a, num_b)}
      _ -> {:error, :einval}
    end
  end

  def eval({:or, a, b}, _) do
    case {to_number(a), to_number(b)} do
      {{:ok, num_a}, {:ok, num_b}} -> {:ok, bor(num_a, num_b)}
      _ -> {:error, :einval}
    end
  end

  def eval({:xor, a, b}, _) do
    case {to_number(a), to_number(b)} do
      {{:ok, num_a}, {:ok, num_b}} -> {:ok, bxor(num_a, num_b)}
      _ -> {:error, :einval}
    end
  end

  def eval({:shift_right, a, b}, _) do
    case {to_number(a), to_number(b)} do
      {{:ok, num_a}, {:ok, num_b}} -> {:ok, num_a >>> num_b}
      _ -> {:error, :einval}
    end
  end

  def eval({:shift_left, a, b}, _) do
    case {to_number(a), to_number(b)} do
      {{:ok, num_a}, {:ok, num_b}} -> {:ok, num_a <<< num_b}
      _ -> {:error, :einval}
    end
  end

  # CATCH-ALL
  # !!! write new evaluations above this definition !!!
  def eval(_expr, _scope), do: {:error, :einval}

  # SPECIAL HANDLING FOR ACCESS

  import Abacus.Tree, only: [reduce: 2]

  defp eval({:access, [{:variable, name} | rest]}, scope, root) do
    case Map.has_key?(scope, name) do
      true -> eval({:access, rest}, Map.get(scope, name, nil), root)
      false -> {:error, {:einkey, name}}
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

  ## ------------------
  ## Helpers
  ## ------------------

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
      nil -> {:error, :einval}
      {:error, :einval} -> {:error, :einval}
      forced_num -> apply(op, [forced_num, num])
    end
  end

  defp compare(op, text1, text2) do
    case {force_number(text1), force_number(text2)} do
      {num1, num2} when is_number(num1) and is_number(num2) -> apply(op, [num1, num2])
      # Fall back to string comparison
      _ -> apply(op, [text1, text2])
    end
  end

  defp compare(op, a, b), do: apply(op, [a, b])

  # Equals
  defp string_equals_number(text, num) when is_binary(text) and is_number(num) do
    case force_number(text) do
      nil -> text == "#{num}"
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

  # When we're testing equality with one item in the list, then do it!
  # This is for legacy reasons where we used to allow X = "string" where X was a multi-select.
  # We no longer allow this condition.
  defp equals([%{"display_text" => text}], str) when is_binary(str), do: str == text
  defp equals(str, [%{"display_text" => text}]) when is_binary(str), do: str == text

  defp equals(
         %{"display_text" => text1, "raw_value" => value1},
         %{"display_text" => text2, "raw_value" => value2}
       ),
       do: text1 == text2 and value1 == value2

  defp equals(str, atom) when is_binary(str) and is_atom(atom), do: str == Atom.to_string(atom)
  defp equals(atom, str) when is_binary(str) and is_atom(atom), do: str == Atom.to_string(atom)
  defp equals(a, b), do: a == b

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

  # Helper to convert strings to numbers for math operations, using existing force_number logic
  defp to_number(val) when is_number(val), do: {:ok, val}

  defp to_number(val) when is_binary(val) do
    case force_number(val) do
      nil -> {:error, :einval}
      {:error, :einval} -> {:error, :einval}
      num -> {:ok, num}
    end
  end

  defp to_number(_), do: {:error, :einval}

  # Helper to convert values to floats for Float.* operations
  defp to_float(val) when is_float(val), do: {:ok, val}
  defp to_float(val) when is_integer(val), do: {:ok, val * 1.0}

  defp to_float(val) when is_binary(val) do
    case force_number(val) do
      nil -> {:error, :einval}
      {:error, :einval} -> {:error, :einval}
      num when is_integer(num) -> {:ok, num * 1.0}
      num when is_float(num) -> {:ok, num}
    end
  end

  defp to_float(_), do: {:error, :einval}

  # Helper to convert values to integers for precision parameters (truncates floats)
  defp to_integer(val) when is_integer(val), do: {:ok, val}
  defp to_integer(val) when is_float(val), do: {:ok, trunc(val)}

  defp to_integer(val) when is_binary(val) do
    case force_number(val) do
      nil -> {:error, :einval}
      {:error, :einval} -> {:error, :einval}
      num when is_integer(num) -> {:ok, num}
      num when is_float(num) -> {:ok, trunc(num)}
    end
  end

  defp to_integer(_), do: {:error, :einval}

  def get_as_flat_list(maybe_value) when is_list(maybe_value),
    do: maybe_value |> List.flatten() |> Enum.reject(&is_nil/1)

  def get_as_flat_list(maybe_value), do: [maybe_value] |> Enum.reject(&is_nil/1)

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
        {num, ""} ->
          num

        # new behaviour to align with JS
        _ ->
          nil
          # old behaviour
          # _ -> {:error, :einval}
      end
    else
      case Integer.parse(string) do
        {num, ""} ->
          num

        # new behaviour to align with JS
        _ ->
          nil
          # old behaviour
          # _ -> {:error, :einval}
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
