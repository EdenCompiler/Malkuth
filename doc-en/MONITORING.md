# Continuous monitoring

The monitor observes architecture changes that happen inside the same long-running Lisp image. It is useful for systems that load plugins, recompile modules or apply runtime patches.

## Launcher

```bash
MALKUTH_BOOTSTRAP_FILE="$PWD/iniciar-meu-app.lisp" \
MALKUTH_SCOPE_PREFIXES='MEU-APP' \
MALKUTH_OUTPUT_DIR="$PWD/build/malkuth-monitor/" \
MALKUTH_WATCH_INTERVAL=10 \
sbcl --script watch.lisp
```

The bootstrap file is loaded before the first snapshot so the monitored application can initialize itself.

## Variables

- `MALKUTH_BOOTSTRAP_FILE`: application bootstrap file;
- `MALKUTH_WATCH_INTERVAL`: seconds between checks;
- `MALKUTH_WATCH_ITERATIONS`: optional maximum number of checks;
- `MALKUTH_EXPORT_ON_CHANGE`: export when topology changes;
- `MALKUTH_HISTORY_RETENTION`: history retention for monitor runs;
- regular scope/output variables also apply.

## Cooperative API

```lisp
(defparameter *monitor*
  (malkuth.monitor:make-architecture-monitor
   :output-directory #P"build/monitor/"))

(malkuth.monitor:monitor-poll! *monitor*)
```

The core does not create threads by itself. Applications may call one iteration from an existing scheduler, use the optional loop, or run polling in their own thread facility.

## Using threads

Keep Lisp image mutation and architecture polling coordinated according to your implementation’s thread-safety rules. Malkuth intentionally does not impose Bordeaux Threads or another concurrency dependency on the portable core.

## Important limitation

The monitor observes the current process only. It does not attach to or introspect another Common Lisp process.
