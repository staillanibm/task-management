-- Create database (will be created by Docker, but included for reference)
-- CREATE DATABASE taskdb;

-- Create extension for UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create task status enum type
DO $$ BEGIN
    CREATE TYPE task_status AS ENUM ('todo', 'inprogress', 'blocked', 'done', 'cancelled');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Create tasks table
CREATE TABLE IF NOT EXISTS tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    creator VARCHAR(255),
    assignee VARCHAR(255),
    status task_status DEFAULT 'todo',
    target_date TIMESTAMP,
    description TEXT,
    comment TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_tasks_assignee ON tasks(assignee);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON tasks(created_at);

-- Create a trigger to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_tasks_updated_at
    BEFORE UPDATE ON tasks
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Insert sample data (optional, for testing)
INSERT INTO tasks (creator, assignee, status, target_date, description, comment)
VALUES
    ('john.doe@example.com', 'jane.smith@example.com', 'todo', '2026-01-20 10:00:00', 'Implement user authentication', 'High priority'),
    ('jane.smith@example.com', 'john.doe@example.com', 'inprogress', '2026-01-18 15:00:00', 'Fix database connection issues', 'Working on it'),
    ('admin@example.com', 'jane.smith@example.com', 'done', '2026-01-15 09:00:00', 'Setup CI/CD pipeline', 'Completed successfully')
ON CONFLICT DO NOTHING;
