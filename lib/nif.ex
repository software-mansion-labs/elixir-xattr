defmodule Xattr.Nif do
	if elem(:os.type(), 0) == :unix do
		# Comment out to test the local implementation, plus edit xattr_native_nif to not throw
		use Rustler, otp_app: Mix.Project.config()[:app], crate: "xattr_nif"
	end

	@spec xattr_native_nif() :: boolean
	def xattr_native_nif() do
		case :os.type() do
			{:win32, _} ->
				false
			{:unix, _} -> 
				:erlang.nif_error(:nif_library_not_loaded)
			_ ->
				:erlang.nif_error(:nif_library_not_loaded)
		end
	end

	@ads_suffix ":ElixirXattr"

	@spec listxattr_nif(binary) :: {:ok, list(binary)} | {:error, term}
	def listxattr_nif(path) do
		unless File.exists? path do
			{:error, :enoent}
		else
			case File.read(path <> @ads_suffix) do
				{:error, :enoent} ->
					{:ok, []} # no file created, but shouldn't error
				{:ok, data} ->
					list = data
						|> Xattr.Windows.parse()
						|> Enum.map(fn {name, _} -> name end)
					{:ok, list}
				error -> error
			end
		end
	end

	@spec hasxattr_nif(binary, binary) :: {:ok, boolean} | {:error, term}
	def hasxattr_nif(path, name) do
		case listxattr_nif(path) do
			{:ok, list} -> {:ok, Enum.member?(list, name)}
			other -> other
		end
	end

	@spec getxattr_nif(binary, binary) :: {:ok, binary} | {:error, term}
	def getxattr_nif(path, name) do
		cond do
			not File.exists? path ->
				{:error, :enoent}
			name =~ "\0" ->
				{:error, "name must not contain null bytes"}
			true -> 
				case File.read(path <> @ads_suffix) do
					{:ok, data} ->
						item = data
							|> Xattr.Windows.parse()
							|> Enum.find(fn {iname, _} -> name == iname end)

						case item do
							{_, value} ->
								{:ok, value}
							nil ->
								{:error, :enoattr}
						end
					error -> error
				end
		end
	end

	@spec setxattr_nif(binary, binary, binary) :: :ok | {:error, term}
	def setxattr_nif(path, name, value) do
		unless File.exists? path do
			{:error, :enoent}
		else
			try do
				# first get other data
				case File.read(path <> @ads_suffix) do
					{:error, :enoent} -> # If no data, just create it
						File.write(path <> @ads_suffix, 
							Xattr.Windows.unparse([{name, value}]))
					{:ok, data} ->
						newdata = data
							|> Xattr.Windows.parse()
							# now add the new data
							|> Map.put(name, value)
							|> Enum.map(&(&1)) # map to list of tuples
							|> Xattr.Windows.unparse()

						File.write(path <> @ads_suffix, newdata) # return as if our own
					error -> error
				end
			catch
				x -> {:error, x}
			end
		end
	end

	@spec removexattr_nif(binary, binary) :: :ok | {:error, term}
	def removexattr_nif(path, name) do
		unless File.exists? path do
			{:error, :enoent}
		else
			try do
				# first get other data
				case File.read(path <> @ads_suffix) do
					{:error, :enoent} -> # If no data, yay!
						{:error, :enoattr}
					{:ok, data} ->
						newdata = data
							|> Xattr.Windows.parse()
							# now remove the attribute
							|> Enum.filter(fn {iname, _} -> iname != name end)
							|> Xattr.Windows.unparse()
						if newdata == data do
							{:error, :enoattr}
						else
							File.write(path <> @ads_suffix, newdata) # return as if our own
						end
					error -> error
				end
			catch
				:e2big -> {:error, :e2big}
				:enotsup -> {:error, :enotsup}
			end
		end
	end
end
