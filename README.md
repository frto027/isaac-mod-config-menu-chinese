# Mod配置菜单（中文版）

本mod基于原作者piber的ModConfigMenu修改而来，并添加了中文本地化的支持。包括

- 中文字体支持。此mod自带一套中文字体，同时也支持切换游戏自带的官中字体。
- 适用于中文的自动换行算法。
- 翻译API支持。在不改变mod逻辑的情况下，可以为现有的mod制作菜单汉化包。
- 纯净模式。
- 若干bug修正。

您可以使用以下方式检测当前的ModConfigMenu是否支持中文。
```lua
if ModConfigMenu then
    if ModConfigMenu.i18n == "Chinese" then
        -- 直接增加中文菜单内容
    else
        -- 增加英文菜单内容
    end
end
```
或者使用以下方式来为现有的英文菜单增加翻译。这有一个好处，就是不会影响到现有菜单的运行（比如，不会改变ModConfigMenu保存菜单项值时使用的key）
```lua
if ModConfigMenu then
    -- 增加英文菜单内容
    if ModConfigMenu.i18n == "Chinese" then
        -- 使用翻译API为您的英文菜单添加翻译
    end
end
```

# 纯净模式

原版Mod配置菜单新增了全局变量SaveHelper、CustomCallbackHelper、FilepathHelper、ScreenHelper、ModConfigMenu、InputHelper。重写了游戏的`Isaac.RegisterMod`函数和`dofile`库函数，并改变了原始`dofile`函数的行为（使其能跨mod调用文件）。

在`纯净模式`下，这些行为均被移除，仅保留ModConfigMenu、ScreenHelper、InputHelper全局变量，不再改变游戏api和lua库函数的行为。
