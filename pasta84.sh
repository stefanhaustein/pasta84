#!/bin/sh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
PASTA80="$DIR/pasta80"
IR4C="$DIR/../build/ir4c"

if [ ! -x "$PASTA80" ]; then
  echo "Error: $PASTA80 not found. Build it with: (cd \"$DIR\" && fpc pasta80.pas)" >&2
  exit 1
fi

if [ ! -x "$IR4C" ]; then
  echo "Error: $IR4C not found. Build IR4th first with: make" >&2
  exit 1
fi

PASTA_OPTS=""
TARGET=""
HAS_OUT=0
HAS_DASHDASH=0
INPUT=""

rem=$#
while [ "$rem" -gt 0 ]; do
  if [ "$HAS_DASHDASH" -eq 1 ]; then
    arg="$1"
    shift
    set -- "$@" "$arg"
    rem=$((rem - 1))
    continue
  fi

  case "$1" in
    --release)
      PASTA_OPTS="$PASTA_OPTS $1"
      shift
      rem=$((rem - 1))
      ;;
    --version)
      exec "$PASTA80" --version
      ;;
    --)
      HAS_DASHDASH=1
      arg="$1"
      shift
      set -- "$@" "$arg"
      rem=$((rem - 1))
      ;;
    -t)
      TARGET="$2"
      arg1="$1"; arg2="$2"
      shift 2
      set -- "$@" "$arg1" "$arg2"
      rem=$((rem - 2))
      ;;
    -o)
      HAS_OUT=1
      arg1="$1"; arg2="$2"
      shift 2
      set -- "$@" "$arg1" "$arg2"
      rem=$((rem - 2))
      ;;
    -b|-I|--platform|--zp|--stack-zp)
      arg1="$1"; arg2="$2"
      shift 2
      set -- "$@" "$arg1" "$arg2"
      rem=$((rem - 2))
      ;;
    -*)
      arg="$1"
      shift
      set -- "$@" "$arg"
      rem=$((rem - 1))
      ;;
    *)
      if [ -z "$INPUT" ]; then
        INPUT="$1"
        shift
        rem=$((rem - 1))
      else
        echo "Error: unexpected argument: $1" >&2
        exit 1
      fi
      ;;
  esac
done

if [ -z "$INPUT" ]; then
  echo "Usage: $(basename "$0") [--release] [-t target] [-o out] [--run] <input.pas> [-- args...]" >&2
  exit 1
fi

"$PASTA80" $PASTA_OPTS "$INPUT"

case "$INPUT" in
  *.pas|*.PAS) STEM="${INPUT%.*}" ;;
  *)           STEM="$INPUT" ;;
esac
IR4="$STEM.ir4"

if [ "$HAS_OUT" -eq 0 ]; then
  case "$TARGET" in
    c64|x16)   EXT="prg" ;;
    cpm)       EXT="com" ;;
    zx81)      EXT="p" ;;
    virt|rv32) EXT="elf" ;;
    obj)       EXT="o" ;;
    bc)        EXT="ir4b" ;;
    *)         EXT="bin" ;;
  esac
  set -- -o "$STEM.$EXT" "$@"
fi

if [ "$HAS_DASHDASH" -eq 1 ]; then
  inserted=0
  rem=$#
  while [ "$rem" -gt 0 ]; do
    if [ "$inserted" -eq 0 ] && [ "$1" = "--" ]; then
      set -- "$@" "$IR4"
      inserted=1
    fi
    arg="$1"
    shift
    set -- "$@" "$arg"
    rem=$((rem - 1))
  done
else
  set -- "$@" "$IR4"
fi

exec "$IR4C" -I "$DIR/rtl" "$@"
