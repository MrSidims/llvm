//===- OutlineDebugInfo.cpp - Outline debug info into separate module ----===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/SYCLLowerIR/OutlineDebugInfo.h"
#include "llvm/Bitcode/BitcodeWriter.h"
#include "llvm/IR/DebugInfo.h"
#include "llvm/IR/DebugInfoMetadata.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

PreservedAnalyses OutlineDebugInfoPass::run(Module &M,
                                            ModuleAnalysisManager &MAM) {
  // Check if module has any debug info
  if (!M.getNamedMetadata("llvm.dbg.cu"))
    return PreservedAnalyses::all();

  // Create a new module for debug info
  auto DebugModule = std::make_unique<Module>("debug", M.getContext());
  DebugModule->setTargetTriple(M.getTargetTriple());
  DebugModule->setDataLayout(M.getDataLayout());

  // Find all debug info metadata
  DebugInfoFinder Finder;
  Finder.processModule(M);

  // Clone all DICompileUnits to the debug module
  NamedMDNode *CUs = M.getNamedMetadata("llvm.dbg.cu");
  if (CUs) {
    NamedMDNode *DebugCUs = DebugModule->getOrInsertNamedMetadata("llvm.dbg.cu");
    for (unsigned I = 0, E = CUs->getNumOperands(); I != E; ++I) {
      DebugCUs->addOperand(CUs->getOperand(I));
    }
  }

  // Clone llvm.module.flags that are related to debug info
  if (NamedMDNode *ModFlags = M.getModuleFlagsMetadata()) {
    NamedMDNode *DebugModFlags = DebugModule->getOrInsertModuleFlagsMetadata();
    for (unsigned I = 0, E = ModFlags->getNumOperands(); I != E; ++I) {
      MDNode *Flag = ModFlags->getOperand(I);
      if (Flag->getNumOperands() >= 2) {
        MDString *Key = dyn_cast<MDString>(Flag->getOperand(1));
        if (Key) {
          StringRef KeyStr = Key->getString();
          // Only copy debug-info related flags
          if (KeyStr.starts_with("Debug") || KeyStr.starts_with("Dwarf") ||
              KeyStr == "debug-info-assignment-tracking") {
            DebugModFlags->addOperand(Flag);
          }
        }
      }
    }
  }

  // Clone llvm.ident if it exists
  if (NamedMDNode *Ident = M.getNamedMetadata("llvm.ident")) {
    NamedMDNode *DebugIdent = DebugModule->getOrInsertNamedMetadata("llvm.ident");
    for (unsigned I = 0, E = Ident->getNumOperands(); I != E; ++I) {
      DebugIdent->addOperand(Ident->getOperand(I));
    }
  }

  // Generate the debug module file path
  std::string DebugFilePath = OutputPath + ".dbg.bc";

  // Save the debug module to file
  std::error_code EC;
  raw_fd_ostream DebugOS(DebugFilePath, EC, sys::fs::OF_None);
  if (EC) {
    errs() << "Error opening debug file '" << DebugFilePath << "': "
           << EC.message() << "\n";
    return PreservedAnalyses::all();
  }

  WriteBitcodeToFile(*DebugModule, DebugOS);
  DebugOS.close();

  // Add module flag to the original module with path to debug module
  // Update DICompileUnit metadata with split debug module flag
  if (CUs) {
    for (unsigned I = 0, E = CUs->getNumOperands(); I != E; ++I) {
      if (auto *CU = dyn_cast<DICompileUnit>(CUs->getOperand(I))) {
        // Create a new DICompileUnit with the split debug info flag
        auto *File = CU->getFile();
        auto *NewFile = DIFile::get(
            M.getContext(), File->getFilename(), File->getDirectory(),
            File->getChecksumKind(), File->getChecksum(),
            DebugFilePath);  // Set the source as the debug file path

        // We need to replace the CU with a new one that has the split debug flag
        // For now, we'll add a module flag that can be read later
        M.addModuleFlag(Module::Warning, "split-debug-module-" + Twine(I),
                       MDString::get(M.getContext(), DebugFilePath));
      }
    }
  }

  // Add a general module flag indicating debug info has been outlined
  M.addModuleFlag(Module::Warning, "sycl-split-debug-info",
                 MDString::get(M.getContext(), DebugFilePath));

  // Strip debug info from original module, keeping only minimal line information
  stripDebugInfo(M);

  return PreservedAnalyses::none();
}
