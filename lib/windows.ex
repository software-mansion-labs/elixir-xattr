defmodule Xattr.Windows do
  # the implementation for the Windows ADS-based backend
  # see nif.ex for the format

  def parse(binary, parsed \\ [])

  def parse(
        <<namelen::size(32)-unsigned-little, namez::binary-size(namelen), vallen::size(32)-unsigned-little,
          value::binary-size(vallen), rest::binary>>,
        parsed
      ) do
    # remove cstr null
    name = binary_part(namez, 0, byte_size(namez) - 1)

    parse(rest, [{name, value} | parsed])
  end

  def parse(<<>>, parsed) do
    Enum.into(parsed, %{})
  end

  defp safe_size(length) do
    if length > 1024 do
      throw(:e2big)
    else
      length
    end
  end

  # Can throw: :e2big, :enotsup
  def unparse(attr, binary \\ <<>>)

  def unparse([{name, value} | rest], binary) do
    # name can't contain a null
    if(name =~ "\0", do: throw("name must not contain null bytes"))
    # Add trailing 0 to make it a c string
    namez = name <> <<0>>

    namelen = safe_size(byte_size(namez))
    vallen = safe_size(byte_size(value))

    unparse(
      rest,
      binary <>
        <<namelen::size(32)-unsigned-little>> <>
        binary_part(namez, 0, namelen - 1) <>
        <<0>> <> <<vallen::size(32)-unsigned-little>> <> binary_part(value, 0, vallen)
    )
  end

  def unparse([], binary) do
    binary
  end
end
