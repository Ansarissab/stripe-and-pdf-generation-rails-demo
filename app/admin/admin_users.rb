ActiveAdmin.register AdminUser do
  permit_params :email, :password, :password_confirmation

  # `parent:` is a Menu ID (String/Symbol), not a label — AA's
  # MenuItem#normalize_id rejects procs. The "Admin" parent group is
  # pre-registered in config/initializers/active_admin.rb with a proc label
  # that resolves through I18n, so the sidebar label is translated even though
  # the lookup string here stays literal.
  menu parent: "Admin", priority: 10

  index do
    selectable_column
    id_column
    column :email
    column :current_sign_in_at
    column :sign_in_count
    column :created_at
    actions
  end

  filter :email
  filter :current_sign_in_at
  filter :sign_in_count
  filter :created_at

  form do |f|
    f.inputs do
      f.input :email
      f.input :password
      f.input :password_confirmation
    end
    f.actions
  end
end
