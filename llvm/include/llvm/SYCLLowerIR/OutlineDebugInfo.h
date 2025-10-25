//===- OutlineDebugInfo.h - Outline debug info into separate module -------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This pass outlines debug information from a module into a separate module.
// The original module is modified to include a module flag that points to
// the debug info module file path.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_SYCLLOWERIR_OUTLINEDEBUGINFO_H
#define LLVM_SYCLLOWERIR_OUTLINEDEBUGINFO_H

#include "llvm/IR/PassManager.h"
#include <string>

namespace llvm {

class Module;

/// Pass that outlines debug information into a separate module.
/// The debug module is saved to OutputPath + ".dbg.bc"
class OutlineDebugInfoPass : public PassInfoMixin<OutlineDebugInfoPass> {
  std::string OutputPath;

public:
  explicit OutlineDebugInfoPass(StringRef OutputPath)
      : OutputPath(OutputPath.str()) {}

  PreservedAnalyses run(Module &M, ModuleAnalysisManager &MAM);
};

} // namespace llvm

#endif // LLVM_SYCLLOWERIR_OUTLINEDEBUGINFO_H
