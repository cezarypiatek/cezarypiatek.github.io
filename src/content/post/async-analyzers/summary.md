| Id | Description | Default Severity |
| -- | ----------- | ----------- |

| AsyncFixer01 |
| AsyncFixer02 |
| AsyncFixer03 |
| AsyncFixer04 |
| AsyncFixer05 |

 Unnecessary async/await usage  | Warning  | 
 Long-running or blocking operations inside an async method |  Warning  | 
 Fire & forget async void methods |  Warning  | 
 Fire & forget async call inside a using block | Warning  | 
 Downcasting from a nested task to an outer task |  Warning  | 

| Code smell | AsyncFixer | Microsoft.VisualStudio.Threading.Analyzers | Roslyn.Analyzers | Meziantou.Analyzer | Roslynator |
| -- | ----------- | ----------- |----------- |----------- |----------- |
| Unnecessary async/await usage  | AsyncFixer01  | | | | RCS1174
| Call sync methods when in an async method |   AsyncFixer02  | VSTHRD103
| Async void methods | AsyncFixer03  | VSTHRD100 | ASYNC0003
| Await Task within using expression | | VSTHRD107 |
| Fire & forget async call inside a using block | AsyncFixer04   |  | | | RCS1229
| Observe result of async calls | | VSTHRD110
| Downcasting from a nested task to an outer task |  AsyncFixer05  | 
| Problematic synchronous waits | | VSTHRD002 | | MA0042, MA0045
| Awaiting foreign Tasks | | VSTHRD003
| Unsupported async delegates | | VSTHRD101	
| Missing `ConfigureAwait(bool)` | | VSTHRD111 | ASYNC0004 | | RCS1090	
| Returning null from a Task-returning method | | VSTHRD114 | | | RCS1210
| Use Async naming convention |  | VSTHRD200 | ASYNC0001 | | RCS1046
| Non asynchronous method names should end with Async | | | ASYNC0002 | | RCS1047|
| Pass cancellation token | | | | MA0040, MA0032 |
| Using cancellation token with IAsyncEnumeration | | | | MA0079,MA0080