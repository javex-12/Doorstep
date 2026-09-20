# Discovery

How a Doorstep device finds another one, and what happens when the easy path is
blocked.

---

## Design rule

Discovery runs several ways **at once**, and the first answer wins. Nothing
waits for the slowest probe, and nothing is trusted just because it answered.

## The three channels

| # | Channel | Speed | Works when |
|---|---|---|---|
| 1 | UDP multicast (v2.1) | fastest | Router passes multicast — most home networks |
| 2 | UDP broadcast on the same interfaces | fast | Router filters multicast but passes broadcast |
| 3 | HTTP subnet sweep | slowest | Everything else |

All three are dispatched together. Results stream into the list as they arrive
instead of appearing only after the slowest probe finishes — a device that is
findable in 50 ms should not wait behind a subnet sweep that takes 10 seconds.

## How UDP discovery works

UDP is **announce only**.

1. A device sends an announcement burst to the multicast group (and, as a
   fallback, to each interface's broadcast address).
2. Every Doorstep instance on the network receives it.
3. Each of them answers over **HTTP** — a unicast register request to the
   announcing device's address. No more UDP.

One socket is bound per interface IPv4 address (`SO_REUSEPORT`/`SO_REUSEADDR` +
`IP_MULTICAST_IF`), because a single socket only ever sends on one interface.
Multicast loopback stays on so two instances on one host can see each other;
own messages are dropped by fingerprint.

IPv6 is a Doorstep extension (group `ff12::fd3a:e420`, enabled by setting
`group_v6`): one `IPV6_V6ONLY` socket per interface, joined by interface index.
`Discovered` carries the source's scope ID, which link-local IPv6 sources need
for the HTTP answer back.

## Paired-device rendezvous

Discovery is not only for strangers. Devices you have already trusted are
probed on app start and then on a quiet background loop, so a laptop you have
used before appears in well under a second even if discovery itself would be
slow. A re-register is idempotent, so a redundant attempt costs nothing.

## Connect uses the advertised port

A discovered device carries its own port in the payload, and connecting always
uses the port the peer advertised rather than an assumed default. A mismatched
port is what used to force manual addressing.

## Manual connect

For networks where *automatic* discovery finds nothing — a router that blocks
both multicast and broadcast — you can type the other device's address. Doorstep
then runs the exact same HTTP discovery against that one address.

Nothing is trusted implicitly: the device still has to answer the Doorstep
handshake, and the user still chooses the trust level exactly as in the
automatic flow.

## When nothing is found

The honest answer, not a spinner forever: Doorstep says what it was doing and
offers the manual address as a stated fallback. And a rule that overrides the
lot — **users never see the words mDNS, multicast, soft AP or transport.** They
see "Looking for your devices…", and then their file arrives.
