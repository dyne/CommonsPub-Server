defmodule CommonsPub.Common.Time do
  alias Timex.Duration

  @doc "Creates a duration from a count and unit"
  def duration_from(count, :day), do: Duration.from_days(count)
  def duration_from(count, :hour), do: Duration.from_hours(count)
  def duration_from(count, :minute), do: Duration.from_minutes(count)
  def duration_from(count, :second), do: Duration.from_seconds(count)
  def duration_from(count, :millisecond), do: Duration.from_milliseconds(count)
  def duration_from(count, :microsecond), do: Duration.from_microseconds(count)

  @doc "Turns a duration into a count of the given unit"
  def duration_to(dur, :day), do: Duration.to_days(dur)
  def duration_to(dur, :hour), do: Duration.to_hours(dur)
  def duration_to(dur, :minute), do: Duration.to_minutes(dur)
  def duration_to(dur, :second), do: Duration.to_seconds(dur)
  def duration_to(dur, :millisecond), do: Duration.to_milliseconds(dur)
  def duration_to(dur, :microsecond), do: Duration.to_microseconds(dur)
end
