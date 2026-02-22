#!/usr/bin/env node
/**
 * MCP Bridge — Direct WebSocket commands to Godot MCP server
 * Usage: node tools/mcp_bridge.mjs <command> [JSON params]
 *
 * Examples:
 *   node tools/mcp_bridge.mjs get_project_info
 *   node tools/mcp_bridge.mjs open_scene '{"path":"res://scenes/MenuOptions.tscn"}'
 *   node tools/mcp_bridge.mjs create_node '{"parent_path":"/root/MenuOptions","node_type":"VBoxContainer","node_name":"Layout"}'
 *   node tools/mcp_bridge.mjs update_node_property '{"node_path":"/root/MenuOptions/Layout","property":"anchors_preset","value":15}'
 *   node tools/mcp_bridge.mjs list_nodes '{"parent_path":"/root/MenuOptions"}'
 *   node tools/mcp_bridge.mjs save_scene
 */
import WebSocket from 'ws';

const command = process.argv[2];
const params = process.argv[3] ? JSON.parse(process.argv[3]) : {};

if (!command) {
  console.error('Usage: node tools/mcp_bridge.mjs <command> [JSON params]');
  console.error('Commands: get_project_info, open_scene, create_node, delete_node,');
  console.error('  update_node_property, get_node_properties, list_nodes,');
  console.error('  create_scene, save_scene, get_current_scene, create_resource');
  process.exit(1);
}

const ws = new WebSocket('ws://localhost:9080');
const cmdId = `bridge_${Date.now()}`;

ws.on('open', () => {
  ws.send(JSON.stringify({ type: command, params, commandId: cmdId }));
});

ws.on('message', (data) => {
  const msg = JSON.parse(data.toString());
  if (msg.commandId === cmdId) {
    if (msg.status === 'success') {
      console.log(JSON.stringify(msg.result, null, 2));
    } else {
      console.error('ERROR:', msg.error || msg.message || JSON.stringify(msg));
    }
    ws.close();
    process.exit(msg.status === 'success' ? 0 : 1);
  }
  // Ignore welcome and other messages
});

ws.on('error', (err) => {
  console.error('WebSocket error:', err.message);
  process.exit(1);
});

// Timeout after 10 seconds
setTimeout(() => {
  console.error('Timeout waiting for response');
  ws.close();
  process.exit(1);
}, 10000);
