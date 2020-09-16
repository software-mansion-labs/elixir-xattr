{type, _} = :os.type()
#type = :win32 # uncomment to test the elixir/windows implementation
ExUnit.configure(exclude: :os, include: [os: type])
ExUnit.start()
