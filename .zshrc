for FILE in ~/zshrc/*; do
    source $FILE
done

# pnpm
export PNPM_HOME="/Users/bfung/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end