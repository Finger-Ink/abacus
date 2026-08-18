defmodule Abacus do
  @moduledoc """
  A math-expression parser, evaluator and formatter for Elixir.

  ## Features

  ### Supported operators

   - `+`, `-`, `/`, `*`
   - Exponentials with `^`
   - Factorial (`n!`)
   - Bitwise operators
     * `<<` `>>` bitshift
     * `&` bitwise and
     * `|` bitwise or
     * `|^` bitwise xor
     * `~` bitwise not (unary)
   - Boolean operators
     * `&&`, `||`, `not`
     * `==`, `!=`, `>`, `>=`, `<`, `<=`
     * Ternary `condition ? if_true : if_false`

  ### Supported functions

   - `sin(x)`, `cos(x)`, `tan(x)`
   - `round(n, precision = 0)`, `ceil(n, precision = 0)`, `floor(n, precision = 0)`

  ### Reserved words

   - `true`
   - `false`
   - `null`

  ### Access to variables in scope

   - `a` with scope `%{"a" => 10}` would evaluate to `10`
   - `a.b` with scope `%{"a" => %{"b" => 42}}` would evaluate to `42`
   - `list[2]` with scope `%{"list" => [1, 2, 3]}` would evaluate to `3`

  ### Data types

   - Boolean: `true`, `false`
   - None: `null`
   - Integer: `0`, `40`, `-184`
   - Float: `0.2`, `12.`, `.12`
   - String: `"Hello World"`, `"He said: \"Let's write a math parser\""`

  If a variable is not in the scope, `eval/2` will result in `{:error, error}`.
  """

  @doc """
  Evaluates the given expression with no scope.

  If `expr` is a string, it will be parsed first.
  """
  @spec eval(expr :: tuple | charlist | String.t()) :: {:ok, result :: number} | {:error, error :: map}
  @spec eval(expr :: tuple | charlist | String.t(), scope :: map) ::
          {:ok, result :: number} | {:error, error :: map}

  @spec eval!(expr :: tuple | charlist | String.t()) :: result :: number
  @spec eval!(expr :: tuple | charlist | String.t(), scope :: map) :: result :: number
  def eval(expr) do
    eval(expr, %{})
  end

  @doc """
  Evaluates the given expression.

  Raises errors when parsing or evaluating goes wrong.
  """
  def eval!(expr) do
    eval!(expr, %{})
  end

  @doc """
  Evaluates the given expression with the given scope.

  If `expr` is a string, it will be parsed first.
  """

  def eval!(expr, scope) do
    case Abacus.Eval.eval(expr, scope) do
      {:ok, result} -> result
      {:error, error} -> raise error
    end
  end

  def eval(expr, scope) when is_binary(expr) or is_bitstring(expr) do
    with {:ok, parsed} <- parse(expr) do
      eval(parsed, scope)
    end
  end

  def eval(expr, scope) do
    Abacus.Tree.reduce(expr, &Abacus.Eval.eval(&1, scope))
  rescue
    # A raise anywhere in evaluation (e.g. Float.round/2 with an
    # out-of-range precision) must surface as an error tuple — one bad
    # expression must never crash a caller's whole render.
    error -> {:error, error}
  end

  @spec format(expr :: tuple | String.t() | charlist) :: {:ok, String.t()} | {:error, error :: map}
  @doc """
  Pretty-prints the given expression.

  If `expr` is a string, it will be parsed first.
  """
  def format(expr) when is_binary(expr) or is_bitstring(expr) do
    case parse(expr) do
      {:ok, expr} ->
        format(expr)

      {:error, _} = error ->
        error
    end
  end

  def format(expr) do
    try do
      {:ok, Abacus.Format.format(expr)}
    rescue
      error -> {:error, error}
    end
  end

  @spec parse(expr :: String.t() | charlist) :: {:ok, expr :: tuple} | {:error, error :: map}
  @doc """
  Parses the given `expr` to a syntax tree.
  """
  def parse(expr) do
    with {:ok, tokens} <- lex(expr) do
      :math_term_parser.parse(tokens)
    else
      {:error, error, _} -> {:error, error}
      {:error, error} -> {:error, error}
    end
  rescue
    # Callers feed arbitrary prose through here and fall back to other
    # handling on {:error, _} — lexing/parsing must never raise.
    error -> {:error, error}
  end

  @doc """
  Returns the unique variable names referenced anywhere in a parsed
  expression — through arithmetic, functions, ternaries and index accesses.

  Accepts the syntax-tree tuple from `parse/1`, or an `{:ok, expr}` parse
  result directly.
  """
  def variables({:ok, expr}), do: variables(expr)

  def variables(expr) do
    expr
    |> collect_variables()
    |> Enum.uniq()
  end

  defp collect_variables({:access, parts}) do
    Enum.flat_map(parts, fn
      {:variable, name} -> [name]
      {:index, index_expr} -> collect_variables(index_expr)
    end)
  end

  defp collect_variables({:function, _name, args}), do: collect_variables(args)

  defp collect_variables(args) when is_list(args),
    do: Enum.flat_map(args, &collect_variables/1)

  defp collect_variables({_operator, a, b, c}),
    do: collect_variables(a) ++ collect_variables(b) ++ collect_variables(c)

  defp collect_variables({_operator, a, b}),
    do: collect_variables(a) ++ collect_variables(b)

  defp collect_variables({_operator, a}), do: collect_variables(a)

  defp collect_variables(_scalar), do: []

  defp lex(string) when is_binary(string) do
    string
    |> String.to_charlist()
    |> lex
  end

  defp lex(string) do
    with {:ok, tokens, _} <- :math_term.string(string) do
      {:ok, tokens}
    end
  end
end
