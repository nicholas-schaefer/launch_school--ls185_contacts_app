desc 'Create empty database'
task :create_db do
  sh 'createdb katalist'
end

desc 'Add schema to Database'
task :create_schema do
  sh 'psql -d katalist < schema.sql;'
end

desc 'Create Database with Schema'
task :create_db_with_schema do
  Rake::Task['create_db'].invoke
  Rake::Task['create_schema'].invoke
end

desc 'Run App'
task :app do
  sh 'ruby app.rb'
end

desc 'Just do this!'
task :default => [:app]
