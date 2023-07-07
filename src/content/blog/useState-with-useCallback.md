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

子组件中没有获取到从 props 中传递过来的最新 state。

1. 父组件中使用 useState 定义变量，并传递给子组件；
2. 子组件中使用 `requestAnimationFrame` 方法，发现在 `requestAnimationFrame` 中 `callback` **调用的 `getState` 没获取到 props 最新的 state。**

```tsx
// 父组件
function App() {
  const [state, setState] = useState(0);

  // 点击时修改 state
  function onChange() {
    setState(preState => ++preState);
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
// 子组件
export default function Children(props) {
  const { state } = props;
  const requestAnimationFrameIdRef = useRef(null);

  function getState() {
    console.log("state", state);
  }

  function requestAnimationFrameCallback() {
    getState();
    requestAnimationFrameIdRef.current = window.requestAnimationFrame(
      requestAnimationFrameCallback
    );
  }

  useEffect(() => {
    requestAnimationFrameCallback();
  }, []);

  return <div>{state}</div>;
}
```

每次调用 changeState 页面上 state 会发生变化，但是 requestAnimationFrame 回调 getState 中不会拿到最新的 state，导致处理逻辑会有问题。

<img src="/assets/1.gif" alt="state change but requestAnimationFrame callback not got">

## 思考

第一反应就是，`requestAnimationFrameCallback` 执行获取的 `state` 是一开始定义 `getState` 时获取的 `state`；之后无论 `requestAnimationFrame` 以如何的速度执行，都不会拿到最新的 `state`。

这就像语文学习的 **《刻舟求剑》**，虽然剑丢下去时马上做了个记号（`getState`），但是船（`requestAnimationFrame`）相对河水的位置一直在变化（调用），如果我们还按照船上的标记去找剑，那肯定是找不到的。

## 方案

### 1. 使用 useRef 大法

不管 `state` 如何变化，只要用 `useEffect` 填上依赖项，都会找到最新的 `state`。这里的 `stateRef` 就像是突破了函数执行，始终能链接到外部的世界。这样的方法也是最简单暴力的。

```tsx
export default function Children(props) {
  const { state } = props;
  const requestAnimationFrameIdRef = useRef(null);
  const stateRef = useRef(state);

  useEffect(() => {
    stateRef.current = state;
  }, [state]);

  function getState() {
    console.log("state", stateRef.current);
  }

  function requestAnimationFrameCallback() {
    getState();
    requestAnimationFrameIdRef.current = window.requestAnimationFrame(
      requestAnimationFrameCallback
    );
  }

  useEffect(() => {
    requestAnimationFrameCallback();
  }, []);

  return <div>{state}</div>;
}
```

<img src="/assets/2.gif" alt="state change with useRef">

这样写的话，会有一个小瑕疵，`useEffect` 中会提示未将 `requestAnimationFrameCallback` 放入依赖项（虽然我在 vim 中未安装对应的插件，这点还是在 codesandbox 中提示的。。。）

<img src="/assets/3.png" alt="required dependencies">

于是我们按照规范的写法，这样就大功告成了。

```tsx
// ...
const requestAnimationFrameCallback = useCallback(() => {
  getState();
  requestAnimationFrameIdRef.current = window.requestAnimationFrame(
    requestAnimationFrameCallback
  );
}, []);

useEffect(() => {
  requestAnimationFrameCallback();
}, [requestAnimationFrameCallback]);
```

### 2. 不使用 useRef

```tsx
const requestAnimationFrameIdRef = useRef(null);

const getState = useCallback(() => {
  console.log("state", state);
}, [state]);

const requestAnimationFrameCallback = useCallback(() => {
  getState();
  requestAnimationFrameIdRef.current = window.requestAnimationFrame(
    requestAnimationFrameCallback
  );
}, [getState]);

useEffect(() => {
  requestAnimationFrameCallback();
}, [requestAnimationFrameCallback]);
```

这样的话，虽然 `react-hooks/exhaustive-deps` 没有任何的警告信息，但是又引发出另一个问题。每次 `state` 变化就会导致 `getState`，然后 `requestAnimationFrameCallback` 变化，又接着触发新的 `requestAnimationFrame` 函数调用。简单来说，`state` 变化一次，`requestAnimationFrame` 也会增加一个。

<img src="/assets/4.gif" alt="required dependencies">

所以需要我们在 `state` 变化的时候，又一次触发 `requestAnimationFrameCallback` 时，立即清除上一次的 `requestAnimationFrame`，就不会存在多次的 `requestAnimationFrame`。

```tsx
useEffect(() => {
  requestAnimationFrameCallback();
  // 清除上一次的 requestAnimationFrameId
  return () => {
    if (requestAnimationFrameIdRef.current) {
      window.cancelAnimationFrame(requestAnimationFrameIdRef.current);
    }
  };
}, [requestAnimationFrameCallback]);
```

<img src="/assets/5.gif" alt="required dependencies">

## 新的问题

多次点击 "change" 按钮，会不会把当前即将要执行的 `requestAnimationFrame` 给取消？我们将 `requestAnimationFrame` 替换成 `setTimeout` 会看得更清晰些。

```tsx
const requestAnimationFrameCallback = useCallback(() => {
  requestAnimationFrameIdRef.current = setTimeout(() => {
    // getState 方法的调用还是需要写在 setTimeout 里面
    // 不然得话，每次 state 变化的时候直接调用 getState
    getState();
    requestAnimationFrameCallback();
  }, 1000);
}, [getState]);

useEffect(() => {
  requestAnimationFrameCallback();
  return () => {
    if (requestAnimationFrameIdRef.current) {
      clearTimeout(requestAnimationFrameIdRef.current);
    }
  };
}, [requestAnimationFrameCallback]);

useEffect(() => {
  // 为了不无限性循环，我们三秒后停止 requestAnimationFrame
  // 写出 3000 并不会调用 3 次 getState，应该和程序执行耗时有关
  // 所以这里写成了 3050
  setTimeout(() => {
    clearTimeout(requestAnimationFrameIdRef.current);
  }, 3050);
}, []);
```

<img src="/assets/6.gif" alt="setTimeout change state">

**能明显看到，本应该 log 3 次，在点击了两次 change 之后，只打印了 2 次。**

所以需要动态计算 `setTimeout` 里面的 1000ms，记录每次点击状态下，已经过去的时间距离 1000ms 还剩下多久时间，这样的话会比较准确触发。如果用的是 `requestAnimationFrame` 的话，可以在 `cancel` 的时候，手动执行一次 `getState`，具体问题具体看待。

## useCallback 的用法

关于 `useCallback` 的方法，网上也有很多示例了，一般是为了解决组件额外的渲染，结合 `useMemo` 一起使用；或是为了解决像上文提到的，和 `useEffect` 一起使用，能够解决获取最新的 `useState`。
