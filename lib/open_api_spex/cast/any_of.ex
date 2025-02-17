defmodule OpenApiSpex.Cast.AnyOf do
  @moduledoc false
  alias OpenApiSpex.Cast
  alias OpenApiSpex.Schema

  def cast(ctx, failed_schemas \\ [], acc \\ nil), do: cast_any_of(ctx, failed_schemas, acc)

  defp cast_any_of(%_{schema: %{anyOf: []}} = ctx, failed_schemas, nil) do
    Cast.error(ctx, {:any_of, error_message(failed_schemas, ctx.schemas)})
  end

  defp cast_any_of(
         %{schema: %{anyOf: [%Schema{} = schema | remaining]}} = ctx,
         failed_schemas,
         acc
       ) do
    relaxed_schema = %{schema | additionalProperties: true, "x-struct": nil}
    new_ctx = put_in(ctx.schema.anyOf, remaining)

    case Cast.cast(%{ctx | schema: relaxed_schema}) do
      {:ok, value} when is_struct(value) ->
        {:ok, value}

      {:ok, value} when is_map(value) ->
        acc =
          value
          |> Enum.reject(fn {k, _} -> is_binary(k) end)
          |> Enum.concat(acc || %{})
          |> Map.new()

        cast_any_of(new_ctx, failed_schemas, acc)

      {:ok, value} ->
        cast_any_of(new_ctx, failed_schemas, acc || value)

      {:error, _} ->
        cast_any_of(new_ctx, [schema | failed_schemas], acc)
    end
  end

  defp cast_any_of(%{schema: %{anyOf: [schema | remaining]}} = ctx, failed_schemas, acc) do
    schema = OpenApiSpex.resolve_schema(schema, ctx.schemas)
    cast_any_of(%{ctx | schema: %{anyOf: [schema | remaining]}}, failed_schemas, acc)
  end

  defp cast_any_of(%_{schema: %{anyOf: [], "x-struct": module}}, _failed_schemas, acc)
       when not is_nil(module),
       do: {:ok, struct(module, acc)}

  defp cast_any_of(%_{schema: %{anyOf: []}}, _failed_schemas, acc), do: {:ok, acc}

  ## Private functions

  defp error_message([], _) do
    "[] (no schemas provided)"
  end

  defp error_message(failed_schemas, schemas) do
    for schema <- failed_schemas do
      schema = OpenApiSpex.resolve_schema(schema, schemas)

      case schema do
        %{title: title, type: type} when not is_nil(title) ->
          "Schema(title: #{inspect(title)}, type: #{inspect(type)})"

        %{type: type} ->
          "Schema(type: #{inspect(type)})"
      end
    end
    |> Enum.join(", ")
  end
end
