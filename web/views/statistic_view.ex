defmodule Notifilter.StatisticView do
  @moduledoc false

  use Notifilter.Web, :view

  def render("index.json", %{data: data}) do
    data
  end
end
