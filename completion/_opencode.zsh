#compdef opencode opencode.sh
# Zsh completion for OpenCode
# 
# This completion script provides intelligent completions for the opencode command,
# including subcommands, options, container names, and image suggestions.

_opencode_containers() {
  local -a names
  names=("${(@f)$(podman ps -a --format '{{.Names}}' 2>/dev/null)}")
  _describe -t containers 'opencode container' names
}

_opencode_images() {
  local -a images
  images=("${(@f)$(podman images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null)}")
  _describe -t images 'container image' images
}

_opencode_workspace_or_args() {
  _alternative \
    'workspace:workspace directory:_files -/' \
    'args:opencode args:_files'
}

_opencode_first_arg() {
  local -a command_names
  command_names=(run shell exec stop killall status rebuild prune help)

  # If the first arg looks like an option, treat it as default "run" options.
  if [[ "$PREFIX" == -* ]]; then
    _opencode_run_shell_opts
    return
  fi

  _wanted commands expl 'opencode command' compadd -a command_names
  _wanted directories expl 'workspace directory' _files -/
}

_opencode_run_shell_opts() {
  _arguments -s \
    '(-w --workspace)-w[Workspace to mount at /workspace]:workspace directory:_files -/' \
    '(-w --workspace)--workspace[Workspace to mount at /workspace]:workspace directory:_files -/' \
    '(-i --image)-i[Use a different image (always pull)]:image:_opencode_images' \
    '(-i --image)--image[Use a different image (always pull)]:image:_opencode_images' \
    '(-v --volume)-v[Extra volume mount host:container with optional options]:volume spec:' \
    '(-v --volume)--volume[Extra volume mount host:container with optional options]:volume spec:' \
    '(-p --publish)-p[Port publish mapping host:container with optional protocol]:port mapping:' \
    '(-p --publish)--publish[Port publish mapping host:container with optional protocol]:port mapping:' \
    '(-e --env)-e[Environment variable KEY=VALUE]:environment variable:' \
    '(-e --env)--env[Environment variable KEY=VALUE]:environment variable:' \
    '(-m --memory)-m[Memory limit (example: 4g)]:memory limit:' \
    '(-m --memory)--memory[Memory limit (example: 4g)]:memory limit:' \
    '--cpu[CPU limit passed to --cpus]:cpu limit:' \
    '--name[Container name]:container name:' \
    '--no-rm[Keep container after exit]' \
    '*::workspace or args:_opencode_workspace_or_args'
}

_opencode() {
  local curcontext="$curcontext" state
  typeset -A opt_args
  local subcmd="${words[2]:-}"

  local -a commands
  commands=(
    'run:Run opencode interactively'
    'shell:Run container with interactive bash shell'
    'exec:Open a second interactive shell in a running container'
    'stop:Stop a container'
    'killall:Stop all opencode containers'
    'status:List opencode containers and mounted workspaces'
    'rebuild:Force rebuild the default opencode image'
    'prune:Prune dangling podman images'
    'help:Show help'
  )

  # Position 1 is the command itself (opencode); position 2 is either
  # a subcommand or a workspace path for the default run behavior.
  if (( CURRENT == 2 )); then
    _opencode_first_arg
    return
  fi

  case "$subcmd" in
    run|shell)
      _opencode_run_shell_opts
      ;;
    exec|stop)
      if (( CURRENT == 3 )); then
        _opencode_containers
      fi
      ;;
    killall|status|rebuild|prune|help)
      ;;
    *)
      _opencode_run_shell_opts
      ;;
  esac
}

compdef _opencode opencode
compdef _opencode opencode.sh
