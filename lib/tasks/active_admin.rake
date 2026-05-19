namespace :active_admin do
  desc "Compile app/assets/stylesheets/active_admin.scss to app/assets/builds/active_admin.css. " \
       "Needed because Propshaft does not process SCSS; AA's stylesheet_link_tag expects a flat .css."
  task :build_css do
    require "sassc"

    aa_gem_dir   = Gem::Specification.find_by_name("activeadmin").gem_dir
    source       = File.expand_path("app/assets/stylesheets/active_admin.scss", Dir.pwd)
    destination  = File.expand_path("app/assets/builds/active_admin.css", Dir.pwd)
    load_paths   = [
      File.dirname(source),
      File.join(aa_gem_dir, "app/assets/stylesheets")
    ]

    css = SassC::Engine.new(File.read(source), load_paths: load_paths, style: :compressed).render
    FileUtils.mkdir_p(File.dirname(destination))
    File.write(destination, css)
    puts "Compiled #{source} -> #{destination} (#{css.bytesize} bytes)"
  end
end

if Rake::Task.task_defined?("assets:precompile")
  Rake::Task["assets:precompile"].enhance([ "active_admin:build_css" ])
end
