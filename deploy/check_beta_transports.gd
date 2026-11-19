extends SceneTree

# Pass the JSON emitted next to a locally deployed signed APK after --.
func _initialize() -> void:
	_verify.call_deferred()

func _verify() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1:
		printerr("Expected the signed APK's metadata JSON path")
		quit(1)
		return
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not meta is Dictionary or meta.get("endpoint_host")!="10.0.2.2" or not meta.get("udp") is Dictionary:
		printerr("Invalid emulator beta network manifest")
		quit(1)
		return
	for service in ["room","solo","party","camp","treasure"]:
		var peer := ENetMultiplayerPeer.new()
		var port := int(meta.udp.get(service,0))
		if port<1 or peer.create_client("127.0.0.1",port)!=OK:
			printerr("Cannot open ",service," UDP ",port)
			quit(1)
			return
		var deadline := Time.get_ticks_msec()+5000
		while peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTING and Time.get_ticks_msec()<deadline:
			peer.poll()
			await process_frame
		if peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:
			printerr("No server handshake at ",service," UDP ",port)
			quit(1)
			return
		print("BETA_UDP_CONNECTED ",service," ",port)
		peer.close()
	print("BETA_TRANSPORT_PASS ",meta.code," five local authority listeners")
	quit()
