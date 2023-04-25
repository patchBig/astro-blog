---
author: Nical Yang
pubDatetime: 2023-04-25T12:15:21.067Z
title: 使用 useCallback and useState 在 VIM 中
postSlug: useState-with-useCallback
featured: true
tags:
  - useState
  - useCallback
description: 在 vim 编辑器中使用 useState 和 useCallback.
---

记录一次在 VIM 编辑器使用 useCallback 的错误姿势

## 问题

父组件中使用 useState 定义变量，并传递给子组件；<br />
子组件中使用 `requestAnimationFrame` 方法，发现在 `requestAnimationFrame` 中 `callback` **调用的 `getState` 没获取到 props 最新的 state。**

```tsx
// 父组件
function App() {
  const [state, setState] = useState(0);

  // 点击时修改 state
  function onChange() {
    setState((preState) => ++preState);
  }

  return (
    <div>
      <Children state={state} />
      <button onClick={onChange}>change</button>
    </div>
  );
}
```

```tsx
xport default function Children(props) {
  const { state } = props;

  function getState() {
    console.log('state', state);
  }

  function requestAnimationFrameCallback() {
    getState();
    window.requestAnimationFrame(requestAnimationFrameCallback);
  }

  useEffect(() => {
    requestAnimationFrameCallback();
  }, [])


  // const requestAnimationFrameIdRef = useRef(null);

  // const requestAnimationFrameDrawImage = useCallback((state) => {
  //   console.log("sss", state);
  //   requestAnimationFrameIdRef.current = window.requestAnimationFrame(() =>
  //     requestAnimationFrameDrawImage(state)
  //   );
  // }, []);

  // useEffect(() => {
  //   if (requestAnimationFrameIdRef.current) {
  //     window.cancelAnimationFrame(requestAnimationFrameIdRef.current);
  //   }
  //   requestAnimationFrameDrawImage(state);
  // }, [requestAnimationFrameDrawImage, state]);

  return <div>{state}</div>;
}
```
