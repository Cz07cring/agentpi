//
//  ContentView.swift
//  AgentPi
//
//  Created by James Rochabrun on 1/11/26.
//

import SwiftUI
import AgentPiCore

/// A simple wrapper view for previewing AgentPiSessionsView.
///
/// The main application now uses `AgentPiSessionsView` directly with
/// `AgentPiProvider` for dependency injection. This ContentView is
/// kept for preview convenience only.
struct ContentView: View {
  @State private var provider = AgentPiProvider()

  var body: some View {
    AgentPiSessionsView()
      .agentPi(provider)
  }
}

#Preview {
  ContentView()
}
