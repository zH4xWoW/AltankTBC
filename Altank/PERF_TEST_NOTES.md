# Altank Stutter Follow-up Note

If stutter is reported again, test these first:
1. Temporarily disable or bypass debuff tracker roster class-availability checks (`updateDebuffTrackerRosterCache`) and compare performance.
2. Temporarily disable or bypass Altank target debuff tracker updates (`updateDebuffTrackerDisplay` / ticker) and compare performance.
3. Compare against the WeakAura debuff tracker behavior, since that one previously did not cause stutter.

Goal: isolate whether Altank's debuff/class availability checks are contributing to frame spikes.
