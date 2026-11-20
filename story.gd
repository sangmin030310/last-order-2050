extends Node

var lead_tiger := false
var hospital_route: StringName
var prepared_route: StringName
var hospital_clue: String
var city_hours: int
var hospital_open: bool
var request_received: bool
var procurement_reviewed: bool
var hospital_restored: bool
var records_linked: bool
var risk_notice_sent: bool
var records_intro_seen: bool
var factory_checked: bool
var reserve_checked: bool
var reserve_approved: bool
var copper_loaded: bool
var relay_record_found: bool
var return_door: StringName
var ending: StringName
var archive_docs: Array[StringName] = []
var copper_scans: Array[StringName] = []
var field_reports: Array[Dictionary] = []

func add_field_report(id: StringName, sender: String, message: String) -> void:
	for report: Dictionary in field_reports:
		if report["id"] == id:
			return
	field_reports.append({"id": id, "sender": sender, "message": message})

func set_field_report(id: StringName, sender: String, message: String) -> void:
	for index in range(field_reports.size()):
		if field_reports[index]["id"] == id:
			field_reports[index] = {"id": id, "sender": sender, "message": message}
			return
	add_field_report(id, sender, message)

func _ready() -> void:
	reset()

func reset() -> void:
	lead_tiger = false
	hospital_route = &""
	prepared_route = &""
	hospital_clue = ""
	city_hours = 72
	hospital_open = false
	request_received = false
	procurement_reviewed = false
	hospital_restored = false
	records_linked = false
	risk_notice_sent = false
	records_intro_seen = false
	factory_checked = false
	reserve_checked = false
	reserve_approved = false
	copper_loaded = false
	relay_record_found = false
	return_door = &""
	ending = &""
	archive_docs.clear()
	copper_scans.clear()
	field_reports.clear()
