defmodule Abacus.Number do
  @moduledoc """
  Numeric coercion: extract a number, cleanly, from whatever a form subject
  entered.

  This module is one half of a cross-engine contract — `extractNumber` in the
  Finger-Ink cloud repo's JS expression engine (`ink_expression.js`) is the
  other half, and both are pinned by the shared `numeric_coercion_cases.json`
  fixture there. Change the two together or not at all.

  The pipeline for strings: trim Unicode whitespace (including NBSP, narrow
  NBSP, thin space and zero-width space), strip one leading or trailing
  currency symbol, strip a trailing percent sign, resolve thousands/decimal
  separators — supporting both `1,180.50` and `1.180,50`; a lone comma with a
  valid 3-digit grouping (`1,500`) defaults to thousands, the AU/NZ/UK
  reading — then parse requiring no leftovers. Floats with a whole value
  collapse to integers so results print the same as JS numbers.
  """

  @zero_width "\u200B"
  @leading_currency ~r/^[$£€¥₹¢₩]/u
  @trailing_currency ~r/[$£€¥₹¢₩]$/u
  @comma_grouping ~r/^\d{1,3}(,\d{3})+$/
  @dot_grouping ~r/^\d{1,3}(\.\d{3})+$/
  @digits_and_separators ~r/^[0-9.,]+$/
  @digits_only ~r/^\d+$/

  @doc """
  Extracts a number for use as an arithmetic operand.

  Returns `{:ok, number}` or `:error`. Blank-ish values — `nil`, empty or
  whitespace-only strings, empty lists — extract as `{:ok, 0}`, matching what
  the browser's `Number()` has always done mid-fill. Junk (`"abc"`) is
  `:error`: blank means zero, garbage does not.
  """
  def extract(value) do
    case classify(value) do
      :blank -> {:ok, 0}
      other -> other
    end
  end

  @doc """
  Like `extract/1`, but blank-ish values are `:error` instead of 0.

  Used for elements inside `sum`/`average`/`min`/`max`, where an unanswered
  entry is dropped rather than counted as zero.
  """
  def extract_strict(value) do
    case classify(value) do
      :blank -> :error
      other -> other
    end
  end

  ## ------------------
  ## Classification: {:ok, number} | :blank | :error
  ## ------------------

  defp classify(number) when is_number(number), do: {:ok, number}
  defp classify(nil), do: :blank
  defp classify([]), do: :blank
  defp classify([single]), do: classify(single)
  # Two or more values are ambiguous — sum()/average() exist for lists.
  defp classify(list) when is_list(list), do: :error

  # Option maps: the first component that yields a number wins (raw value
  # first, display text second); a blank component defers rather than
  # counting as zero. Fully-blank options are blank; junk makes it an error.
  defp classify(%{"raw_value" => raw, "display_text" => display}) do
    case {classify(raw), classify(display)} do
      {{:ok, number}, _} -> {:ok, number}
      {_, {:ok, number}} -> {:ok, number}
      {:blank, :blank} -> :blank
      _ -> :error
    end
  end

  defp classify(string) when is_binary(string) do
    case trim(string) do
      "" ->
        :blank

      trimmed ->
        trimmed
        |> strip_currency()
        |> trim()
        |> strip_percent()
        |> trim()
        |> parse_number()
    end
  end

  defp classify(_other), do: :error

  ## ------------------
  ## String pipeline
  ## ------------------

  # String.trim/1 covers Unicode whitespace (NBSP, narrow NBSP, thin space);
  # zero-width space is not Unicode whitespace, so it needs its own pass.
  defp trim(string) do
    string
    |> String.trim()
    |> String.trim(@zero_width)
    |> String.trim()
  end

  # At most one currency symbol, leading or trailing.
  defp strip_currency(string) do
    stripped = Regex.replace(@leading_currency, string, "")

    if stripped == string do
      Regex.replace(@trailing_currency, string, "")
    else
      stripped
    end
  end

  defp strip_percent(string), do: String.replace_suffix(string, "%", "")

  defp parse_number(string) do
    {sign, unsigned} = split_sign(string)

    with true <- Regex.match?(@digits_and_separators, unsigned),
         {:ok, normalised} <- normalise_separators(unsigned),
         {:ok, number} <- exact_parse(normalised) do
      {:ok, apply_sign(number, sign)}
    else
      _ -> :error
    end
  end

  defp split_sign("-" <> rest), do: {-1, rest}
  defp split_sign("+" <> rest), do: {1, rest}
  defp split_sign(string), do: {1, string}

  defp apply_sign(number, 1), do: number
  defp apply_sign(number, -1), do: -number

  defp normalise_separators(string) do
    comma? = String.contains?(string, ",")
    dot? = String.contains?(string, ".")

    cond do
      comma? and dot? -> resolve_mixed_separators(string)
      comma? -> resolve_comma_only(string)
      true -> {:ok, string}
    end
  end

  # Both separators present: the last one is the decimal point and the other
  # must group correctly ("1.180,50" and "1,180.50" both → 1180.50).
  defp resolve_mixed_separators(string) do
    {decimal, grouping} =
      if last_index(string, ",") > last_index(string, "."),
        do: {",", "."},
        else: {".", ","}

    with [int_part, frac_part] <- String.split(string, decimal),
         true <- valid_grouping?(int_part, grouping),
         true <- Regex.match?(@digits_only, frac_part) do
      {:ok, String.replace(int_part, grouping, "") <> "." <> frac_part}
    else
      _ -> :error
    end
  end

  # Comma only: valid 3-digit grouping reads as thousands (the home-market
  # default for the one genuinely ambiguous form, "1,500"); any other single
  # comma can only be a decimal comma ("72,5").
  defp resolve_comma_only(string) do
    cond do
      Regex.match?(@comma_grouping, string) ->
        {:ok, String.replace(string, ",", "")}

      length(String.split(string, ",")) == 2 ->
        {:ok, String.replace(string, ",", ".")}

      true ->
        :error
    end
  end

  defp last_index(string, separator) do
    {position, _length} = :binary.matches(string, separator) |> List.last()
    position
  end

  defp valid_grouping?(int_part, ","), do: Regex.match?(@comma_grouping, int_part)
  defp valid_grouping?(int_part, "."), do: Regex.match?(@dot_grouping, int_part)

  # Exact parse, no leftovers. "5." and ".5" are padded first so both engines
  # accept them the way JS Number() does.
  defp exact_parse(""), do: :error

  defp exact_parse(string) do
    if String.contains?(string, ".") do
      string |> pad_decimal() |> parse_float()
    else
      parse_integer(string)
    end
  end

  defp pad_decimal("." <> _rest = string), do: pad_decimal("0" <> string)

  defp pad_decimal(string) do
    if String.ends_with?(string, "."), do: string <> "0", else: string
  end

  defp parse_float(string) do
    case Float.parse(string) do
      {number, ""} -> {:ok, integer_if_possible(number)}
      _ -> :error
    end
  end

  defp parse_integer(string) do
    case Integer.parse(string) do
      {number, ""} -> {:ok, number}
      _ -> :error
    end
  end

  # Collapses whole-valued floats to integers (`5.0` → `5`) so numbers render
  # identically to JS, which has no int/float distinction.
  defp integer_if_possible(float) do
    truncated = trunc(float)
    if truncated == float, do: truncated, else: float
  end
end
