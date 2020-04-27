defmodule Status.Metric.Tracer do
  @moduledoc """
  Trace requests and reports information to Datadog via Spandex
  """

  use Spandex.Tracer, otp_app: :status
end
