using System.Collections.Concurrent;
using Mishon.Application.Interfaces;

namespace Mishon.API.Realtime;

public class ChatConnectionTracker : IChatConnectionTracker
{
    private readonly ConcurrentDictionary<int, HashSet<string>> _connections = new();
    private readonly object _sync = new();

    public void AddConnection(int userId, string connectionId)
    {
        lock (_sync)
        {
            if (!_connections.TryGetValue(userId, out var userConnections))
            {
                userConnections = [];
                _connections[userId] = userConnections;
            }

            userConnections.Add(connectionId);
        }
    }

    public void RemoveConnection(int userId, string connectionId)
    {
        lock (_sync)
        {
            if (!_connections.TryGetValue(userId, out var userConnections))
            {
                return;
            }

            userConnections.Remove(connectionId);
            if (userConnections.Count == 0)
            {
                _connections.TryRemove(userId, out _);
            }
        }
    }

    public bool IsUserConnected(int userId)
    {
        lock (_sync)
        {
            return _connections.TryGetValue(userId, out var userConnections) &&
                   userConnections.Count > 0;
        }
    }
}
