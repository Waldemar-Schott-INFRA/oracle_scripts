#!/bin/bash

LOG_FILE=${ACONSO_SCHEDULER_LOG:-/var/aconso/log/scheduler.log}

if [[ ! -r "$LOG_FILE" ]]; then
	printf '3 "Aconso Scheduler" - Logdatei nicht lesbar: %s\n' "$LOG_FILE"
	exit 0
fi

LC_ALL=C awk '
function save_block(complete,    state, message) {
	if (job == "") return
	if (job == "null" && candidate != "" && protocol_start != "" && block_start == protocol_start) {
		job = candidate
	}
	if (!complete || errors !~ /^[0-9]+$/ || warnings !~ /^[0-9]+$/ || end_time == "") {
		state = 3
		message = "Unvollstaendiger oder ungueltiger Execution-Info-Block"
		metrics[job] = "-"
	} else {
		state = errors > 0 ? 2 : (warnings > 0 ? 1 : 0)
		message = "Ende: " end_time ", Fehler: " errors ", Warnungen: " warnings
		metrics[job] = "errors=" errors "|warnings=" warnings
	}
	states[job] = state
	messages[job] = message
	jobs[job] = 1
	job = ""
}
{
	sub(/\r$/, "")
}
/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].*\[aconso[.]server[.]Scheduler[.]/ || /^-+.*[[:space:]]protocol[[:space:]]*-+[[:space:]]*$/ {
	task_name = task_start = ""
	task_ambiguous = 0
}
job == "" && /^-[[:space:]]*start time[[:space:]]*:/ {
	task_start = $0
	sub(/^[^:]*:[[:space:]]*/, "", task_start)
	sub(/[[:space:]]*$/, "", task_start)
	next
}
job == "" && /^-[[:space:]]*parameter[[:space:]]+taskName[[:space:]]*:/ {
	name = $0
	sub(/^[^:]*:[[:space:]]*/, "", name)
	sub(/[[:space:]]*$/, "", name)
	if (task_name != "" && task_name != name) task_ambiguous = 1
	task_name = name
	next
}
/^-+[[:space:]]*Execution Info[[:space:]]*-/ {
	save_block(0)
	job = $0
	sub(/^-+[[:space:]]*Execution Info[[:space:]]*-[[:space:]]*/, "", job)
	sub(/[[:space:]]*-+[[:space:]]*$/, "", job)
	candidate = !task_ambiguous && task_name != "null" ? task_name : ""
	protocol_start = task_start
	task_name = task_start = ""
	task_ambiguous = 0
	errors = warnings = end_time = block_start = ""
	next
}
job != "" && /^info[[:space:]]*-[[:space:]]*start time[[:space:]]*:/ {
	block_start = $0
	sub(/^[^:]*:[[:space:]]*/, "", block_start)
	sub(/[[:space:]]*$/, "", block_start)
	next
}
job != "" && /^info[[:space:]]*-[[:space:]]*errors[[:space:]]*:/ {
	errors = $0
	sub(/^[^:]*:[[:space:]]*/, "", errors)
	sub(/[[:space:]]*$/, "", errors)
	next
}
job != "" && /^info[[:space:]]*-[[:space:]]*warnings[[:space:]]*:/ {
	warnings = $0
	sub(/^[^:]*:[[:space:]]*/, "", warnings)
	sub(/[[:space:]]*$/, "", warnings)
	next
}
job != "" && /^info[[:space:]]*-[[:space:]]*end time[[:space:]]*:/ {
	end_time = $0
	sub(/^[^:]*:[[:space:]]*/, "", end_time)
	sub(/[[:space:]]*$/, "", end_time)
	next
}
job != "" && /^-+[[:space:]]*$/ {
	save_block(1)
}
END {
	save_block(0)
	count = 0
	for (name in jobs) {
		service = name
		gsub(/["\\]/, "_", service)
		printf "%d \"Aconso Job %s\" %s %s\n", states[name], service, metrics[name], messages[name]
		count++
	}
	if (count == 0) print "3 \"Aconso Scheduler\" - Keine Execution-Info-Bloecke gefunden"
}' "$LOG_FILE"
