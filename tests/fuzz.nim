import drchaos
import nosc

proc fuzzMe(s: string) =
    try:
        discard nosc.parseMessage(s)
    except OscParseError:
        discard

defaultMutator(fuzzMe)