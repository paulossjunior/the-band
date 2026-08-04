# Dialyzer warnings intentionally ignored.
#
# This file exists from the first delivery on purpose: without it, dialyxir prints
#
#     No :ignore_warnings opt specified in mix.exs and default does not exist.
#
# on every run, which trains everyone to skim past the gate's output. See
# specs/001-phoenix-foundation-governance/research.md R3.
#
# Adding an entry here means accepting a warning permanently. Every entry MUST carry a
# comment saying why the warning is wrong or unavoidable. An entry without a reason is a
# suppressed defect, and the constitution forbids hiding errors to make a gate pass.
#
# Empty is the correct state. Dialyzer currently reports zero warnings on
# Elixir 1.20.2 / OTP 29 (verified — research.md R3).
[]
