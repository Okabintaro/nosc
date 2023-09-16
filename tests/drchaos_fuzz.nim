import drchaos
import nosc

proc fuzzMe(s: string) =
    # The function being tested.
    try:
        discard nosc.parseMessage(s)
    except OscParseError:
        discard



# proc fuzzTarget(data: (string, 0)) =
#   let (s) = data[0]
#   fuzzMe(s)


defaultMutator(fuzzMe)