defmodule Notifilter.Notifier do
  use Ecto.Model

  schema "notifiers" do
    field :application, :string
    field :event_name, :string
    field :template, :string
    field :rules, {:array, :map}
    field :notification_type, :string
    field :target, :string

    # timestamps(inserted_at: :created_at)
  end
end
