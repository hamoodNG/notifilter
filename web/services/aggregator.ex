defmodule Notifilter.Statistics do
  defstruct [:total, :buckets, :name]
end

defmodule Notifilter.Aggregator do
  @moduledoc """
  Gathers statistics about your data
  """

  def status do
    headers = [{"Content-type", "application/json"}]
    host()
    |> HTTPoison.get(headers)
    |> handle_response
  end

  def query(body) do
    url = "#{host()}/notifilter/event/_search?pretty=true"
    headers = [{"Content-type", "application/json"}]
    {:ok, response} = HTTPoison.post(url, body, headers)
    response.body
  end

  def aggregate(event_name, aggregation_type, field) do
    url = "#{host()}/notifilter/event/_search"
    # Need to assign it to a temp variable instead of doing it in the map
    # because of [1], will be fixed in Elixir 1.3.
    # [1]: https://github.com/elixir-lang/elixir/commit/b2e8c1451ec1315e58c6b15c66e7558c9f8ba1ab,
    query_field = "data.#{field}"

    tendaysago = Timex.shift(Timex.now(), days: -10)
    min_date = Timex.format!(tendaysago, "%F", :strftime)

    query = %{
      size: 0,
      query: %{
        bool: %{
          must: %{
            match: %{
              name: event_name
            }
          },
          filter: %{
            range: %{
              received_at: %{
                gte: "now-10d/d",
                lte: "now/d"
              }
            }
          }
        }
      },
      aggs: %{
        per_day: %{
          date_histogram: %{
            field: "received_at",
            interval: "day",
            min_doc_count: 0,
            extended_bounds: %{
              min: min_date
            }
          },
          aggs: %{
            "aggregation_field" => %{
              aggregation_type => %{
                field: query_field
              },
              aggs: %{
                total: %{
                  value_count: %{
                    field: query_field
                  }
                }
              }
            }
          }
        }
      }
    }

    body = Poison.encode!(query)

    headers = [{"Content-type", "application/json"}]
    HTTPoison.post(url, body, headers)
    |> handle_response
    |> convert
  end

  defp convert(es_response) when is_map(es_response) do
    data = es_response["aggregations"]["per_day"]["buckets"]

    %Notifilter.Statistics{
      name: "root",
      total: es_response["hits"]["total"],
      buckets: Enum.map(data, fn x -> convert_bucket(x) end)
    }
  end

  defp convert_bucket(es_response = %{"aggregation_field" => _}) do
    data =
      if es_response["aggregation_field"]["buckets"] do
        Enum.map(es_response["aggregation_field"]["buckets"], fn x -> convert_bucket(x) end)
      end

    %Notifilter.Statistics{
      name: es_response["key_as_string"],
      total: es_response["doc_count"],
      buckets: data
    }
  end

  defp convert_bucket(es_response = %{"total" => total}) do
    %Notifilter.Statistics{
      name: es_response["key"],
      total: total["value"]
    }
  end

  defp handle_response({_, response}) do
    Poison.decode!(response.body)
  end

  defp host() do
    Application.get_env(:notifilter, Elasticsearch)[:host]
  end
end
