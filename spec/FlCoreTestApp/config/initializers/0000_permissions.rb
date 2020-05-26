# Register permissions used by this application

Fl::Core::Access::Permission::Owner.new.register_with_report
Fl::Core::Access::Permission::Create.new.register_with_report
Fl::Core::Access::Permission::Read.new.register_with_report
Fl::Core::Access::Permission::Write.new.register_with_report
Fl::Core::Access::Permission::Delete.new.register_with_report
Fl::Core::Access::Permission::Index.new.register_with_report
Fl::Core::Access::Permission::IndexContents.new.register_with_report
Fl::Core::Access::Permission::CreateContents.new.register_with_report
Fl::Core::Access::Permission::Edit.new.register_with_report
Fl::Core::Access::Permission::Manage.new.register_with_report

Fl::Core::Actor::Permission::ManageMembers.new.register_with_report
