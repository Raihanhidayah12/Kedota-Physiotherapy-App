# App performance checklist

The automated suite is a repeatable baseline for the checklist in the Jira
work item. Run the host/device-independent checks with:

```powershell
flutter test test/performance/performance_checklist_test.dart
flutter test test/performance/crypto_benchmark_test.dart
```

Run on a physical low-end Android device (not only a simulator) for a
representative device result. The automated timing limits are guardrails; retain
the printed measurements with the device, OS, build mode, and test date.

| Checklist item | Automated coverage | Physical-device verification |
| --- | --- | --- |
| CPU usage | Repeated SHA-256 workload and crypto workload timing; logs elapsed time as a CPU-work proxy. | Profile a release build in Android Studio CPU Profiler or Xcode Instruments. Record app CPU utilization at idle and during the same flows; Flutter tests cannot report reliable OS-level CPU percentages. |
| Memory usage | Reads process RSS and logs the delta while an 8 MiB buffer is retained. | Use Android Studio Memory Profiler / Xcode Instruments to check peak RSS, Dart heap, and growth while navigating screens and loading images. |
| Battery consumption | No stable automated battery-drain assertion: OS battery counters are device-wide, coarse, and affected by background activity. | On Android, reset `adb shell dumpsys batterystats --reset`, run a fixed 15-minute flow with screen brightness/network recorded, then collect `adb shell dumpsys batterystats <applicationId>` (or Android Studio Energy Profiler). On iOS, use Xcode Instruments Energy Log. Repeat at least three times and report the average; compare idle and active runs. |
| API response handling | Uses a deterministic Dio adapter to verify encrypted request serialization, response decryption, and preservation of HTTP 503 status/body. Logs local request/response handling time. | Measure real endpoint latency separately; record p50/p95 and error rate on the same network. Do not treat the stub-adapter duration as network latency. |
| Image loading speed | Loads and decodes the bundled logo asset, logs dimensions/bytes/time, and enforces a generous 5-second CI ceiling. | Measure cold and warm image loads on Wi-Fi and mobile data for the profile and appointment images; record p50/p95 and verify placeholders/error states. |
| Performance on older devices | Runs a conservative 2,000-operation encryption workload with a 30-second guardrail. | Run the release build on the oldest supported physical device (record model, Android/iOS version, RAM). Repeat the main sign-in, booking, profile-image, and history flows; check frame jank, startup time, memory, and API behavior. A simulator or host test does not certify older hardware. |

## Interpreting results

The CPU workload timing is elapsed time, not a direct CPU-utilization
percentage. The RSS delta is an observation, not a leak verdict: allocator and
garbage-collector behavior can vary across runs. Battery and older-device
certification require the physical-device procedure above and should not be
marked complete from unit-test results alone.

## Release configuration

The `update-pin` Edge Function now requires an encrypted request and returns an
encrypted success envelope. Set `REST_ENCRYPT_KEY` and `REST_HMAC_KEY` in the
Edge Function secrets before deploying it, and deploy the matching app version.
See [Supabase Functions setup](../supabase/functions/README.md).
