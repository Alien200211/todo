import React, { useState, useEffect } from 'react';
import './App.css';

function App() {
  const [todos, setTodos] = useState([]);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const API_URL = process.env.REACT_APP_API_URL || '/api';

  useEffect(() => {
    fetchTodos();
  }, []);

  const fetchTodos = async () => {
    try {
      setLoading(true);
      const response = await fetch(`${API_URL}/todos`);
      if (!response.ok) throw new Error('Failed to fetch todos');
      const data = await response.json();
      setTodos(data);
      setError('');
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const addTodo = async (e) => {
    e.preventDefault();
    if (!title.trim()) {
      setError('Title is required');
      return;
    }

    try {
      const response = await fetch(`${API_URL}/todos`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title, description })
      });
      if (!response.ok) throw new Error('Failed to add todo');
      const newTodo = await response.json();
      setTodos([newTodo, ...todos]);
      setTitle('');
      setDescription('');
      setError('');
    } catch (err) {
      setError(err.message);
    }
  };

  const toggleTodo = async (todo) => {
    try {
      const response = await fetch(`${API_URL}/todos/${todo.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ completed: !todo.completed })
      });
      if (!response.ok) throw new Error('Failed to update todo');
      const updated = await response.json();
      setTodos(todos.map(t => t.id === todo.id ? updated : t));
    } catch (err) {
      setError(err.message);
    }
  };

  const deleteTodo = async (id) => {
    try {
      const response = await fetch(`${API_URL}/todos/${id}`, {
        method: 'DELETE'
      });
      if (!response.ok) throw new Error('Failed to delete todo');
      setTodos(todos.filter(t => t.id !== id));
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="container">
      <div className="card">
        <h1>📝 Todo App</h1>
        <p className="subtitle">Learn Infrastructure by Deploying This App</p>

        {error && <div className="error">{error}</div>}

        <form onSubmit={addTodo} className="form">
          <input
            type="text"
            placeholder="What needs to be done?"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            className="input"
          />
          <textarea
            placeholder="Add a description (optional)"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            className="textarea"
          />
          <button type="submit" className="btn btn-primary">
            Add Todo
          </button>
        </form>

        <div className="stats">
          Total: {todos.length} | Completed: {todos.filter(t => t.completed).length}
        </div>

        {loading ? (
          <div className="loading">Loading...</div>
        ) : todos.length === 0 ? (
          <div className="empty">No todos yet. Create one to get started!</div>
        ) : (
          <div className="todos-list">
            {todos.map((todo) => (
              <div key={todo.id} className={`todo-item ${todo.completed ? 'completed' : ''}`}>
                <div className="todo-content">
                  <input
                    type="checkbox"
                    checked={todo.completed}
                    onChange={() => toggleTodo(todo)}
                    className="checkbox"
                  />
                  <div className="todo-text">
                    <div className="todo-title">{todo.title}</div>
                    {todo.description && <div className="todo-description">{todo.description}</div>}
                  </div>
                </div>
                <button
                  onClick={() => deleteTodo(todo.id)}
                  className="btn btn-delete"
                >
                  Delete
                </button>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

export default App;
