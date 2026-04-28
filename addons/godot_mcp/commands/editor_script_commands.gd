@tool
class_name MCPEditorScriptCommands
extends MCPBaseCommandProcessor

func process_command(client_id: int, command_type: String, params: Dictionary, command_id: String) -> bool:
	match command_type:
		"execute_editor_script":
			_execute_editor_script(client_id, params, command_id)
			return true
	return false  # Command not handled

func _execute_editor_script(client_id: int, params: Dictionary, command_id: String) -> void:
	var code = params.get("code", "")
	
	# Validation
	if code.is_empty():
		return _send_error(client_id, "Code cannot be empty", command_id)
	
	# Create a temporary script node to execute the code
	var script_node := Node.new()
	script_node.name = "EditorScriptExecutor"
	add_child(script_node)
	
	# Create a temporary script
	var script = GDScript.new()
	
	var output = []
	var error_message = ""
	var execution_result = null
	
	# Replace print() calls with custom_print() in the user code
	var modified_code = _replace_print_calls(code)
	
	# Use consistent tab indentation in the template
	var script_content = """@tool
extends Node

signal execution_completed

# Variable to store the result
var result = null
var _output_array = []
var _error_message = ""
var _parent

# Custom print function that stores output in the array
func custom_print(values):
	# Convert array of values to a single string
	var output_str = ""
	if values is Array:
		for i in range(values.size()):
			if i > 0:
				output_str += " "
			output_str += str(values[i])
	else:
		output_str = str(values)
		
	_output_array.append(output_str)
	print(output_str)  # Still print to the console for debugging

func run():
	print("Executing script... ready func")
	_parent = get_parent()
	var scene = get_tree().edited_scene_root
	
	# Execute the provided code
	var err = _execute_code()
	
	# If there was an error, store it
	if err != OK:
		_error_message = "Failed to execute script with error: " + str(err)
	
	# Signal that execution is complete
	execution_completed.emit()

func _execute_code():
	# USER CODE START
{user_code}
	# USER CODE END
	return OK
"""
	
	# Process the user code to ensure consistent indentation
	# This helps prevent "mixed tabs and spaces" errors
	var processed_lines = []
	var lines = modified_code.split("\n")
	for line in lines:
		# Replace any spaces at the beginning with tabs
		var processed_line = line
		
		# If line starts with spaces, replace with a tab
		var space_count = 0
		for i in range(line.length()):
			if line[i] == " ":
				space_count += 1
			else:
				break
		
		# If we found spaces at the beginning, replace with tabs
		if space_count > 0:
			# Create tabs based on space count (e.g., 4 spaces = 1 tab)
			var tabs = ""
			for _i in range(space_count / 4): # Integer division
				tabs += "\t"
			processed_line = tabs + line.substr(space_count)
			
		processed_lines.append(processed_line)
	
	var indented_code = ""
	for line in processed_lines:
		indented_code += "\t" + line + "\n"
	
	script_content = script_content.replace("{user_code}", indented_code)
	script.source_code = script_content
	
	# Check for script errors during parsing
	var error = script.reload()
	if error != OK:
		remove_child(script_node)
		script_node.queue_free()
		return _send_error(client_id, "Script parsing error: " + str(error), command_id)
	
	# Assign the script to the node
	script_node.set_script(script)
	
	# Connect to the execution_completed signal
	script_node.connect("execution_completed", _on_script_execution_completed.bind(script_node, client_id, command_id))

	script_node.run()


# Signal handler for when script execution completes
func _on_script_execution_completed(script_node: Node, client_id: int, command_id: String) -> void:
	# Collect results safely by checking if properties exist
	var execution_result = script_node.get("result")
	var output = script_node._output_array
	var error_message = script_node._error_message
	
	# Clean up
	remove_child(script_node)
	script_node.queue_free()
	
	# Build the response
	var result_data = {
		"success": error_message.is_empty(),
		"output": output
	}

	print("result_data: ", result_data)
	
	if not error_message.is_empty():
		result_data["error"] = error_message
	elif execution_result != null:
		result_data["result"] = execution_result
	
	_send_success(client_id, result_data, command_id)

# Replace print() calls with custom_print() in the user code
func _replace_print_calls(code: String) -> String:
	# C38 — Paren-balance scanner instead of regex.
	# The previous regex `print\s*\(([^\)]+)\)` failed on any nested call like
	# `print(str(node))` — it captured `str(node` (stopped at first `)`)
	# producing `custom_print([str(node])` which fails to parse (error 43).
	# Walk char-by-char tracking depth so we match the BALANCED paren pair.
	var modified: String = ""
	var i: int = 0
	var n: int = code.length()
	while i < n:
		# Look for a print( token at this position (must be at start or after
		# non-identifier char so we don't mangle e.g. `myprint(`).
		var is_word_boundary: bool = (i == 0) or not _is_ident_char(code[i - 1])
		if is_word_boundary and code.substr(i, 5) == "print":
			# Skip whitespace between `print` and `(`.
			var j: int = i + 5
			while j < n and code[j] == " ":
				j += 1
			if j < n and code[j] == "(":
				# Find the matching `)` honoring nested parens.
				var depth: int = 1
				var k: int = j + 1
				while k < n and depth > 0:
					var ch: String = code[k]
					if ch == "(":
						depth += 1
					elif ch == ")":
						depth -= 1
					k += 1
				if depth == 0:
					var arg_content: String = code.substr(j + 1, k - j - 2)
					modified += "custom_print([" + arg_content + "])"
					i = k
					continue
		modified += code[i]
		i += 1
	return modified


func _is_ident_char(c: String) -> bool:
	return c.length() > 0 and (c == "_" or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9"))
