MRuby::Gem::Specification.new('mruby-onig-regexp') do |spec|
  spec.license = 'MIT'
  spec.authors = 'mattn'

  def spec.bundle_onigmo
    return if @onigmo_bundled
    @onigmo_bundled = true

    require 'open3'

    # remove libonig
    linker.libraries = []

    version = '5.15.0'
    onig_src_dir = "#{dir}/Onigmo-#{version}"
    onig_build_dir = "#{build_dir}/Onigmo-#{version}"
    oniguruma_lib = libfile "#{onig_build_dir}/.libs/libonig"
    unless ENV['OS'] == 'Windows_NT'
      oniguruma_lib = libfile "#{onig_build_dir}/.libs/libonig"
    else
      oniguruma_lib = libfile "#{onig_build_dir}/onig_s"
    end
    header = "#{onig_src_dir}/oniguruma.h"

    task :clean do
      FileUtils.rm_rf [onig_build_dir]
    end

    FileUtils.mkdir_p onig_build_dir

    def run_command(env, command)
      STDOUT.sync = true
      Open3.popen2e(env, command) do |stdin, stdout, thread|
        print stdout.read
        fail "#{command} failed" if thread.value != 0
      end
    end

    libonig_objs_dir = "#{onig_build_dir}/libonig_objs"
    libmruby_a = libfile("#{build.build_dir}/lib/libmruby")

    file oniguruma_lib => header do |t|
      Dir.chdir(onig_build_dir) do
        e = {
          'CC' => "#{build.cc.command} #{build.cc.flags.join(' ')}",
          'CXX' => "#{build.cxx.command} #{build.cxx.flags.join(' ')}",
          'LD' => "#{build.linker.command} #{build.linker.flags.join(' ')}",
          'AR' => build.archiver.command }
        unless ENV['OS'] == 'Windows_NT'
          run_command e, "#{onig_src_dir}/configure --disable-shared --enable-static"
          run_command e, 'make'
        else
          # FIXME!
          run_command e, "make -f #{onig_src_dir}/Makefile.mingw"
        end
      end

      FileUtils.mkdir_p libonig_objs_dir
      Dir.chdir(libonig_objs_dir) { `ar x #{oniguruma_lib}` }
      file libmruby_a => Dir.glob("#{libonig_objs_dir}/*.o")
    end

    file libmruby_a => Dir.glob("#{libonig_objs_dir}/*.o") if File.exists? oniguruma_lib

    file "#{dir}/src/mruby_onig_regexp.c" => oniguruma_lib
    cc.include_paths << onig_src_dir
  end


  if build.kind_of? MRuby::CrossBuild or
      (build.cc.respond_to? :search_header_path and build.cc.search_header_path 'oniguruma.h')
    spec.linker.libraries << 'onig'
  else
    spec.bundle_onigmo
  end
end
