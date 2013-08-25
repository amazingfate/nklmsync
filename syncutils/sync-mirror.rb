#!/usr/bin/env ruby

#######################################################################
#
# by Ng Cheuk-fung
# TODO:
#       1. To write synchronization *status* to a single log file, need
#          to synchronizing write access.
#       2. Multi source support.
#       3. Auto sent a mail about failed synchornization to admin.
#
#######################################################################

require 'optparse'

@RsyncDest = "/ftp/ftp"
@LogDest = "/ftp/syncutils/sync_logs"
@LockDest = "/ftp/syncutils/sync_update_state"

class Mirror
  attr_reader :src, :srcV6, :exclude
  def initialize(src, srcV6, exclude)
    @src = src
    @srcV6 = srcV6
    @exclude = exclude
  end
end

Archlinux = Mirror.new(
  "rsync://mirrors.4.tuna.tsinghua.edu.cn/archlinux",
  "rsync://mirrors.6.tuna.tsinghua.edu.cn/archlinux",
  "--exclude=.* --exclude=iso/ --exclude=Archive-Update-in-Progress*"
)

CentOS = Mirror.new(
  "rsync://mirrors.4.tuna.tsinghua.edu.cn/centos",
  "rsync://mirrors.6.tuna.tsinghua.edu.cn/centos",
  "--exclude=.* --exclude=*.iso --exclude=Archive-Update-in-Progress*"
)

Fedora = Mirror.new(
  "rsync://mirrors.4.tuna.tsinghua.edu.cn/fedora",
  "rsync://mirrors.6.tuna.tsinghua.edu.cn/fedora",
  "--exclude=.* --exclude=*.iso --exclude=Archive-Update-in-Progress*"
)

EPEL = Mirror.new(
  "rsync://mirrors.4.tuna.tsinghua.edu.cn/epel",
  "rsync://mirrors.6.tuna.tsinghua.edu.cn/epel",
  "--exclude=.* --exclude=4/ --exclude=4AS --exclude=4ES --exclude=4WS --exclude=testing/4/ --exclude=testing/4AS --exclude=testing/4ES --exclude=testing/4WS --exclude=RPM-GPG-KEY-EPEL-4 --exclude=Archive-Update-in-Progress*"
)

RPMFusion = Mirror.new(
  "rsync://mirrors.4.tuna.tsinghua.edu.cn/rpmfusion",
  "rsync://mirrors.6.tuna.tsinghua.edu.cn/rpmfusion",
  "--exclude=.* --exclude=free/fedora/releases/8/ --exclude=free/fedora/releases/9/ --exclude=free/fedora/updates/8/ --exclude=free/fedora/updates/9/ --exclude=free/fedora/updates/testing/8/ --exclude=free/fedora/updates/testing/9/ --exclude=nonfree/fedora/releases/8/ --exclude=nonfree/fedora/releases/9/ --exclude=nonfree/fedora/updates/8/ --exclude=nonfree/fedora/updates/9/ --exclude=nonfree/fedora/updates/testing/8/ --exclude=nonfree/fedora/updates/testing/9/ --exclude=Archive-Update-in-Progress*"
)

Gentoo = Mirror.new(
  "rsync://mirrors.4.tuna.tsinghua.edu.cn/gentoo",
  "rsync://mirrors.6.tuna.tsinghua.edu.cn/gentoo",
  "--exclude=.* --exclude=*.iso --exclude=experimental/ --exclude=releases/ --exclude=Archive-Update-in-Progress*"
)

GentooPortage = Mirror.new(
  "rsync://mirrors.4.tuna.tsinghua.edu.cn/gentoo-portage",
  "rsync://mirrors.6.tuna.tsinghua.edu.cn/gentoo-portage",
  "--exclude=.* --exclude=Archive-Update-in-Progress*"
)

LinuxMint = Mirror.new(
  "rsync://mirrors.4.tuna.tsinghua.edu.cn/linuxmint",
  "rsync://mirrors.6.tuna.tsinghua.edu.cn/linuxmint",
  "--exclude=.* --exclude=*.iso --exclude=Archive-Update-in-Progress*"
)

Ubuntu = Mirror.new(
  "rsync://mirrors.4.tuna.tsinghua.edu.cn/ubuntu",
  "rsync://mirrors.6.tuna.tsinghua.edu.cn/ubuntu",
  "--exclude=.* --exclude=*.iso --exclude=Archive-Update-in-Progress*"
)

RubyGems = Mirror.new(
  "rsync://mirrors.4.tuna.tsinghua.edu.cn/rubygems",
  "rsync://mirrors.6.tuna.tsinghua.edu.cn/rubygems",
  "--exclude=.* --exclude=Archive-Update-in-Progress*"
)

MirrorList = {
  "archlinux"	=> Archlinux,
  "centos"	=> CentOS,
  "fedora"	=> Fedora,
  "epel"	=> EPEL,
  "rpmfusion"	=> RPMFusion,
  "gentoo"	=> Gentoo,
  "gentoo-portage"	=> GentooPortage,
  "linuxmint"	=> LinuxMint,
  "ubuntu"	=> Ubuntu,
  "rubygems"	=> RubyGems
}

@options = {:ipv4 => true}
begin
  opts = OptionParser.new do |opts|
    opts.banner = "sync-mirror\n    A tool synchronizes linux mirrors with rsync."

    opts.separator ""
    opts.separator "USAGE"
    opts.separator "    sync-mirror.rb [OPTIONS]"

    opts.separator ""
    opts.separator "OPTIONS"

    opts.on("-r", "--repo [REPO]",
            String,
            "Specific repository to be synchronized.",
            "[archlinux|centos|fedora|epel|rpmfusion|gentoo|gentoo-portage|linuxmint|ubuntu|rubygems]") do |r|
      raise "repository required!" if r == nil
      raise "invalid repository: #{r}" unless MirrorList.keys.include? r
      @options[:repo] = r
            end

    opts.on("-a", "--all-repos", "Synchronizes all repositories ignoring the -r option.") do
      @options[:all] = true
    end

    opts.on("-4", "--ipv4", "Synchronizes repositories with IPv4 addresses only. Enables by deafult.") do
    end

    opts.on("-6", "--ipv6", "Synchronizes repositories with IPv6 addresses only ignoring the -4 option.") do
      @options[:ipv4] = false
      @options[:ipv6] = true
    end

    opts.on("-n", "--dry-run", "Performs a trial run with no changes made.") do
      @options[:dry] = true
    end

    opts.on("-v", "--[no-]verbose", "Enables verbose mode and prints synchronization details during its running.", "Warning: HUGE output!") do |v|
      @options[:verbose] = v
    end

    opts.on_tail("-h", "--help", "Show this message.") do
      puts opts
      exit
    end
  end

  opts.parse!
rescue
  puts $!
  puts
  puts opts
  exit
end

if @options[:repo] == nil and @options[:all] == nil
  puts "repository required!"
  puts
  puts opts
  exit
end

def sync(repo, cmd)
  lockFile = "#{@LockDest}/updating-#{repo}"
  return 0 if File.exist? lockFile

  system "touch #{lockFile}"

  logFile = "\"#{@LogDest}/#{repo}_#{Time.new.strftime("%Y%m%d-%H")}.log\""
  if @options[:verbose]
    log = " | tee -a #{logFile}"
  else
    log = " >> #{logFile}"
  end

  system "touch #{logFile} 2>&1 #{log}"
  system "echo \"===================================================\" #{log}"
  system "echo \">> Starting sync on $(date --rfc-2822)\" #{log}"
  system "echo \">> ---\" #{log}"
  system "echo #{log}"

  system "echo \">> Using the following command:\" #{log}"
  system "echo \"#{cmd.gsub('"', '\"')}\" #{log}"
  system "echo #{log}"

  system "echo \">> Sync Infomation\" #{log}"
  syncStatus = system "#{cmd} 2>&1 #{log}"
  system "echo #{log}"

  if syncStatus
    system "echo \"$(date +%s)\" > #{@RsyncDest}/#{repo}/lastsync"

    system "echo \">> ---\" #{log}"
    system "echo \">> Finished sync on $(date --rfc-2822)\" #{log}"
    system "echo \"===================================================\" #{log}"

    system "rm #{lockFile}"
  else
    system "echo \">> ---\" #{log}"
    system "echo \">> Error! Aborted sync on $(date --rfc-2822)\" #{log}"
    system "echo \"===================================================\" #{log}"

    system "mv #{lockFile} #{@LockDest}/update-#{repo}-FAIL_#{Time.new.strftime("%Y%m%d-%H")}"
  end

  return syncStatus
end

RsyncCMD = "rsync --recursive --times --verbose --links --hard-links --stats --no-p --no-o --no-g --delete --delete-excluded --delete-after #{@options[:ipv6] ? '--ipv6' : ''} #{@options[:dry] ? '--dry-run' : ''}"

if @options[:all]
  status = 1
  MirrorList.each_pair do |name, mirror|
    cmd = "#{RsyncCMD} #{mirror.exclude} #{@options[:ipv6] ? mirror.srcV6 : mirror.src} \"#{@RsyncDest}/#{name}\""
    status = status and sync(name, cmd)
    sleep 5
  end
else
  name = @options[:repo]
  mirror = MirrorList[name]
  cmd = "#{RsyncCMD} #{mirror.exclude} #{@options[:ipv6] ? mirror.srcV6 : mirror.src} \"#{@RsyncDest}/#{name}\""
  status = sync(name, cmd)
end

exit status
