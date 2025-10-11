{ pkgs, lib, ... }:
{
  name = "sysbox";
  meta = {
    maintainers = with lib.maintainers; [ ];
  };

  nodes = {
    docker =
      { pkgs, ... }:
      {
        virtualisation.sysbox.enable = true;
        virtualisation.docker.enable = true;

        # Ensure enough resources for system containers
        virtualisation.memorySize = 2048;
        virtualisation.cores = 2;
      };
  };

  testScript = ''
    docker.start()

    docker.wait_for_unit("sysbox-mgr.service")
    docker.wait_for_unit("sysbox-fs.service")
    docker.wait_for_unit("docker.service")

    with subtest("sysbox services are running"):
        docker.succeed("systemctl is-active sysbox-mgr.service")
        docker.succeed("systemctl is-active sysbox-fs.service")

    with subtest("sysbox binaries are available"):
        docker.succeed("command -v sysbox-runc")
        docker.succeed("command -v sysbox-mgr")
        docker.succeed("command -v sysbox-fs")

    with subtest("docker has sysbox-runc runtime configured"):
        docker.succeed("docker info | grep -i sysbox-runc")

    with subtest("run a simple container with sysbox-runc via docker"):
        docker.succeed("tar cv --files-from /dev/null | docker import - scratchimg")
        docker.succeed(
            "docker run --runtime=sysbox-runc -d --name=sleeping "
            "-v /nix/store:/nix/store -v /run/current-system/sw/bin:/bin "
            "scratchimg /bin/sleep 30"
        )
        docker.succeed("docker ps | grep sleeping")
        docker.succeed("docker stop sleeping")
        docker.succeed("docker rm sleeping")

    with subtest("verify sysctl settings"):
        docker.succeed("[ $(cat /proc/sys/fs/inotify/max_queued_events) -ge 1048576 ]")
        docker.succeed("[ $(cat /proc/sys/fs/inotify/max_user_watches) -ge 1048576 ]")
        docker.succeed("[ $(cat /proc/sys/fs/inotify/max_user_instances) -ge 1048576 ]")
  '';
}
