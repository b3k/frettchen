defmodule Frettchen.SpanTest do
  use ExUnit.Case, async: true

  alias Frettchen.{Span, Trace}

  describe "closing a span" do

    test "close/1 closes a span and calculates the duration" do
      span =
        Frettchen.Trace.start("foo", [configuration: %{%Frettchen.Configuration{} | reporter: :null}])
        |> Frettchen.Span.open("bar")
      span = Span.close(span)
      assert span.duration > 0
    end

  end

  describe "extract a span" do
    test "returns the id components of a serialized span" do
      span =
        Frettchen.Trace.start("foo", [configuration: %{%Frettchen.Configuration{} | reporter: :null}])
        |> Frettchen.Span.open("bar")
      inject = "#{Integer.to_string(span.trace_id_low, 16)}:#{Integer.to_string(span.span_id, 16)}:#{Integer.to_string(span.parent_span_id,16)}:1"
      assert Span.extract(inject) == %{trace_id_low: span.trace_id_low, span_id: span.span_id, parent_span_id: span.parent_span_id}
    end
  end

  describe "inject a span" do
    test "serializes a span so it can be sent between processes" do
      span =
        Frettchen.Trace.start("foo", [configuration: %{%Frettchen.Configuration{} | reporter: :null}])
        |> Frettchen.Span.open("bar")
      assert Span.inject(span) == "#{Integer.to_string(span.trace_id_low, 16)}:#{Integer.to_string(span.span_id, 16)}:#{Integer.to_string(span.parent_span_id,16)}:1"
    end
  end

  describe "opening a span" do

    test "open/2 creates a new span struct with a passed name and a passed span as the parent" do
      parent = 
        Frettchen.Trace.start("foo")
        |> Frettchen.Span.open("bar")
      span = Span.open(parent, "bar")
      assert span.span_id != parent.span_id
      assert span.parent_span_id == parent.span_id
      assert span.trace_id_low == parent.trace_id_low
    end

    test "open/2 registers a span with its parent's trace process" do
      parent = 
        Frettchen.Trace.start("foo")
        |> Frettchen.Span.open("bar")
      span = Span.open(parent, "bar")
      trace = Trace.get(span)
      assert trace.spans[span.span_id] == span
    end

    test "open/2 creates a new span struct with a passed name and a passed trace as the trace id" do
      trace = Frettchen.Trace.start("foo")
      span = Span.open(trace, "foo")
      assert span.trace_id_low == trace.id
    end

    test "open/2 registers a span with its associated trace process" do
      span =
        Frettchen.Trace.start("foo")
        |> Span.open("bar")

      trace = Trace.get(span)
      assert trace.spans[span.span_id] == span
    end

    test "open/3 registers a span with its parent's span id" do
      parent = 
        Frettchen.Trace.start("foo")
        |> Frettchen.Span.open("bar")
      trace = Trace.get(parent)
      span = Span.open(trace, "bar", parent.span_id)
      trace = Trace.get(span)
      assert trace.spans[span.span_id] == span
    end
  end

  describe "add a log to a span" do

    setup do
      span = 
        Frettchen.Trace.start("foo")
        |> Frettchen.Span.open("bar")
      {:ok, span: span} 
    end

    test "log/3 adds a new log with a tag value", %{span: span} do
      span = Span.log(span, "foo", "bar")
      log = hd(span.logs)
      tag = hd(log.fields)
      assert tag.key == "foo"
      assert tag.v_str == "bar"
      assert tag.v_type == 0
      refute log.timestamp == nil
    end

  end

  describe "add a tag to a span" do

    setup do
      span = 
        Frettchen.Trace.start("foo")
        |> Frettchen.Span.open("bar")
      {:ok, span: span} 
    end

    test "tag/3 adds a new tag with a string value", %{span: span} do
      span = Span.tag(span, "foo", "bar")
      tag = hd(span.tags)
      assert tag.key == "foo"
      assert tag.v_str == "bar"
      assert tag.v_type == 0
    end

    test "tag/3 adds a new tag with a float value", %{span: span} do
      span = Span.tag(span, "foo", 3.14)
      tag = hd(span.tags)
      assert tag.key == "foo"
      assert tag.v_double == 3.14 
      assert tag.v_type == 1
    end

    test "tag/3 adds a new tag with a boolean value", %{span: span} do
      span = Span.tag(span, "foo", false)
      tag = hd(span.tags)
      assert tag.key == "foo"
      assert tag.v_bool == false 
      assert tag.v_type == 2
    end
    
    test "tag/3 adds a new tag with an integer value", %{span: span} do
      span = Span.tag(span, "foo", 42)
      tag = hd(span.tags)
      assert tag.key == "foo"
      assert tag.v_long == 42 
      assert tag.v_type == 3
    end
  end
end
