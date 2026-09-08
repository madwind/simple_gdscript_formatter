## Compatibility entry point for explicitly requested organization.
const MemberOrganizer = preload("../transform/member_organizer.gd")


static func apply(code: String) -> String:
	return MemberOrganizer.new().organize(code)
