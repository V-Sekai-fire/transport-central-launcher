defmodule CentralLauncher.Payload do
  @moduledoc "The operating system a staged file was built for, from its magic bytes."

  def os_of(<<0xCF, 0xFA, 0xED, 0xFE, _::binary>>), do: :darwin
  def os_of(<<0xCE, 0xFA, 0xED, 0xFE, _::binary>>), do: :darwin
  def os_of(<<0xCA, 0xFE, 0xBA, 0xBE, _::binary>>), do: :darwin
  def os_of(<<0x7F, "ELF", _::binary>>), do: :linux
  def os_of(<<"MZ", _::binary>>), do: :windows
  def os_of(_other), do: :unknown

  def os_of_target("macos" <> _), do: :darwin
  def os_of_target("linux" <> _), do: :linux
  def os_of_target("windows" <> _), do: :windows
  def os_of_target(_other), do: :unknown

  def check(contents, target) do
    found = os_of(contents)
    want = os_of_target(target)

    if found == :unknown or want == :unknown or found == want do
      :ok
    else
      {:mismatch, found, want}
    end
  end
end
