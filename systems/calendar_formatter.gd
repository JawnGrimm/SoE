class_name CalendarFormatter
extends RefCounted

static func format_year(year: int) -> String:
	if year <= 0:
		return "%d BCE" % (1 - year)
	return "%d CE" % year

static func format_date(era: EraDef, year: int, period: int) -> String:
	var period_text := _format_period(era, period)
	var year_text := format_year(year)
	if era == null or era.display_name.is_empty():
		return "%s • %s" % [period_text, year_text]
	return "%s • %s • %s" % [era.display_name, period_text, year_text]

static func _format_period(era: EraDef, period: int) -> String:
	var period_number := maxi(period, 0)
	if era != null and not era.period_names.is_empty():
		var periods_per_name := maxi(1, WorldState.PERIODS_PER_YEAR / era.period_names.size())
		var name_index := clampi(floori(float(period_number) / float(periods_per_name)), 0, era.period_names.size() - 1)
		return era.period_names[name_index]
	var label := "Period" if era == null or era.period_label.is_empty() else era.period_label
	return "%s %02d" % [label, period_number + 1]
