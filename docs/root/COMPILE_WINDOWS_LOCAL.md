# 🔨 Compilation Locale Windows - Guide Rapide

## ✅ Prérequis Vérifiés

Votre PC a:
- ✅ Visual Studio 2022 (Community + Enterprise)
- ✅ CMake (version 4.2.0)
- ✅ Ninja (version 1.13.0)

## 🚀 Étapes de Compilation

### **1. Ouvrir le bon terminal**

**Menu Démarrer** → Tapez: `x64 native tools`
Cliquez sur: **"x64 Native Tools Command Prompt for VS 2022"**

### **2. Compiler godot-cpp**

```batch
cd c:\Users\PGNK2128\Godot-MCP\native\godot-cpp
scons platform=windows target=template_release arch=x86_64 -j8
```

⏱️ **Durée:** ~5-8 minutes

### **3. Compiler llama.cpp**

```batch
cd c:\Users\PGNK2128\Godot-MCP\native\llama.cpp
mkdir build
cd build
cmake .. -G Ninja ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DBUILD_SHARED_LIBS=OFF ^
  -DLLAMA_CURL=OFF ^
  -DGGML_OPENMP=OFF ^
  -DLLAMA_BUILD_EXAMPLES=OFF ^
  -DLLAMA_BUILD_TESTS=OFF
ninja
```

⏱️ **Durée:** ~3-5 minutes

### **4. Compiler merlin_llm.dll**

```batch
cd c:\Users\PGNK2128\Godot-MCP\native
mkdir build
cd build
cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Release
ninja
```

⏱️ **Durée:** ~2 minutes

### **5. Vérifier la DLL**

```batch
dir ..\addons\merlin_llm\bin\*.dll
```

Vous devriez voir: `merlin_llm.windows.release.x86_64.dll`

---

## 🆘 Si Erreurs

### ❌ "scons: command not found"
```batch
pip install scons
```

### ❌ "Cannot find godot-cpp library"
Relancez l'étape 2 (godot-cpp)

### ❌ "Cannot find llama library"
Relancez l'étape 3 (llama.cpp)

---

## 🎯 Avantages de la Compilation Locale

✅ Pas de cross-compilation (MinGW problématique)
✅ Bibliothèques Windows natives
✅ Pas de problèmes de threading/mutex
✅ Plus rapide (pas de upload/download)
✅ Support complet MSVC

---

**Total estimé:** 15-20 minutes vs Colab avec patchs complexes

**Recommandation:** Essayez la compilation locale d'abord! 🚀
