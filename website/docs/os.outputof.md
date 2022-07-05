Runs a shell command and return the output.

```lua
result, errorCode = os.outputof("command", "streams")
```

### Parameters ###

`command` is a shell command to run.

`streams` indicates which standard stream content to retrieve.
Value must be one of
* `"both"` (the default) Retrieve content emitted on both output and error stream.
* `"output"` Retrieve content emitted on the standard output stream only.
* `"error"` Retrieve content emitted on the standard error stream only.

### Return Value ###

On command execution success
1. The content emitted by the program on the selected stream(s).
2. The exit code of the program. It should always be 0 in this case.
3. The exit reason (`"exit"` or `"signal"`)

On error
1. `nil`
2. The exit code of the program. It should always be a non-zero value.
3. The exit reason
4. The content emitted by the program on the selected stream(s).

### Availability ###

Premake 4.0 or later.


### Examples ###

```lua
-- Get the ID for the host processor architecture
local proc = os.outputof("uname -p")
```

```lua
local text, exitcode, type, err = os.outputof("an_unreliable_command --random")
if exitcode == 0 then
  print ("Ok", text)
else
  print ("Failed", err)
end
```


### See Also ###

* [os.executef](os.executef.md)
